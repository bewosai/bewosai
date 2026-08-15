import logging
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from rest_framework import status, generics, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from bewosai.email import send_otp_email
from bewosai.permissions import BusinessNotArchivedForWrites, require_feature
from bewosai.utils import get_bid, get_business
from .models import User, Business, StaffMember, OTPCode, LoginActivity, ACCOUNT_PERSONAL, ACCOUNT_BUSINESS
from .serializers import (
    UserSerializer, BusinessSerializer, StaffMemberSerializer, InviteStaffSerializer,
    SendOTPSerializer, VerifyOTPSerializer, GoogleLoginSerializer,
)

logger = logging.getLogger(__name__)


class _RequireStaffManagement:
    """Gated by the Super Admin 'Staff Management' feature switch."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, require_feature("staff_management")]


def api_response(success, message, status_code, **extra):
    return Response({"success": success, "message": message, **extra}, status=status_code)


def _first_error(errors):
    """Flatten DRF's {field: [messages]} error dict into one readable string."""
    for field, messages in errors.items():
        text = str(messages[0]) if isinstance(messages, list) else str(messages)
        return f"{field}: {text}" if field != "non_field_errors" else text
    return "Invalid request."


class SendOTPView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "otp_send"

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(False, _first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        is_signup = serializer.validated_data["is_signup"]

        existing = User.objects.filter(email=email).first()

        # Reject explicit sign-up attempts for already-registered emails
        if is_signup and existing:
            return api_response(
                False, "This email is already registered. Please sign in instead.",
                status.HTTP_400_BAD_REQUEST, user_exists=True,
            )

        wait = OTPCode.seconds_until_resend(email)
        if wait > 0:
            return api_response(
                False, f"Please wait {wait}s before requesting another code.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )

        account_type = existing.account_type if existing else ACCOUNT_BUSINESS
        otp, code = OTPCode.generate(email, account_type)

        # Send synchronously and report the real outcome. This used to fire
        # on a background thread so the request returned instantly, but that
        # meant an SMTP/SendGrid failure was only ever visible in the server
        # log — the client always got "success": true even when no email
        # ever went out, which made real delivery failures undebuggable from
        # the app. The extra second or two of latency is worth the honesty.
        if not send_otp_email(email, code):
            logger.error("Failed to send OTP email to %s", email)
            otp.delete()
            return api_response(
                False,
                "Couldn't send the verification email right now. Please try again in a moment.",
                status.HTTP_502_BAD_GATEWAY,
            )

        logger.info("OTP sent for %s (new_account=%s)", email, existing is None)

        return api_response(
            True, f"OTP sent to {email}. Valid for 10 minutes.", status.HTTP_200_OK,
            user_exists=existing is not None,
        )


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "otp_verify"

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(False, _first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        code = serializer.validated_data["code"]
        remember = serializer.validated_data["remember"]
        name = serializer.validated_data["name"]

        otp, error_code = OTPCode.verify_and_consume(email, code)

        if error_code == "too_many_attempts":
            logger.warning("OTP locked out for %s after too many attempts", email)
            return api_response(
                False, "Too many incorrect attempts. Please request a new code.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )
        if error_code == "expired":
            logger.warning("Expired OTP attempt for %s", email)
            return api_response(False, "This code has expired. Please request a new one.", status.HTTP_400_BAD_REQUEST)
        if error_code:
            logger.warning("Invalid OTP attempt for %s", email)
            return api_response(False, "Incorrect code. Please check and try again.", status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            user = User.objects.filter(email=email).first()
            is_new = user is None
            if is_new:
                # account_type is a placeholder here; the user picks it via set-account-type
                user = User.objects.create_user(
                    email=email,
                    name=name or email.split("@")[0].capitalize(),
                    account_type=ACCOUNT_BUSINESS,
                    is_verified=True,
                )

            user.last_login_at = timezone.now()
            user.is_verified = True
            user.save(update_fields=["last_login_at", "is_verified"])

            LoginActivity.objects.create(
                user=user,
                ip_address=request.META.get("REMOTE_ADDR"),
                user_agent=request.META.get("HTTP_USER_AGENT", ""),
            )

        logger.info("User %s logged in via OTP (new_user=%s)", email, is_new)

        return _login_response(user, is_new, remember)


class GoogleLoginView(APIView):
    """
    Exchanges a Google ID token (obtained client-side via google_sign_in) for
    our own JWT pair — same find-or-create-by-email + response shape as
    VerifyOTPView, so the Flutter app's post-login flow is unaffected by
    which method the user signed in with.
    """

    permission_classes = [permissions.AllowAny]
    throttle_scope = "otp_verify"

    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(False, _first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)

        if not settings.GOOGLE_OAUTH_CLIENT_ID:
            logger.error("Google sign-in attempted but GOOGLE_OAUTH_CLIENT_ID is not configured")
            return api_response(False, "Google sign-in is not configured.", status.HTTP_503_SERVICE_UNAVAILABLE)

        try:
            payload = google_id_token.verify_oauth2_token(
                serializer.validated_data["id_token"],
                google_requests.Request(),
                audience=settings.GOOGLE_OAUTH_CLIENT_ID,
            )
        except ValueError:
            logger.warning("Google sign-in rejected: invalid id_token")
            return api_response(False, "Invalid Google sign-in token.", status.HTTP_400_BAD_REQUEST)

        email = (payload.get("email") or "").strip().lower()
        if not email:
            return api_response(False, "Google account has no email address.", status.HTTP_400_BAD_REQUEST)
        if not payload.get("email_verified"):
            return api_response(False, "This Google account's email isn't verified.", status.HTTP_400_BAD_REQUEST)

        remember = serializer.validated_data["remember"]

        with transaction.atomic():
            user = User.objects.filter(email=email).first()
            is_new = user is None
            if is_new:
                user = User.objects.create_user(
                    email=email,
                    name=payload.get("name") or email.split("@")[0].capitalize(),
                    account_type=ACCOUNT_BUSINESS,
                    is_verified=True,
                )

            user.last_login_at = timezone.now()
            user.is_verified = True
            user.save(update_fields=["last_login_at", "is_verified"])

            LoginActivity.objects.create(
                user=user,
                ip_address=request.META.get("REMOTE_ADDR"),
                user_agent=request.META.get("HTTP_USER_AGENT", ""),
            )

        logger.info("User %s logged in via Google (new_user=%s)", email, is_new)

        return _login_response(user, is_new, remember)


def _login_response(user, is_new, remember):
    refresh = RefreshToken.for_user(user)
    if remember:
        refresh.set_exp(lifetime=timedelta(days=30))
        refresh.access_token.set_exp(lifetime=timedelta(days=30))

    businesses = Business.objects.filter(staff__user=user, staff__is_active=True, status="ACTIVE")

    return api_response(
        True, "Login successful.", status.HTTP_200_OK,
        access=str(refresh.access_token),
        refresh=str(refresh),
        user=UserSerializer(user).data,
        is_new_user=is_new,
        # New user needs to select their profile type (personal vs business)
        needs_profile_setup=is_new,
        businesses=BusinessSerializer(businesses, many=True).data,
    )


class LogoutView(APIView):
    def post(self, request):
        try:
            RefreshToken(request.data.get("refresh")).blacklist()
        except Exception:
            logger.exception("Token blacklist failed during logout for user %s", request.user.id)
        # Record logout
        last_login = LoginActivity.objects.filter(user=request.user, logout_time__isnull=True).first()
        if last_login:
            now = timezone.now()
            last_login.logout_time = now
            last_login.session_duration = now - last_login.timestamp
            last_login.save(update_fields=["logout_time", "session_duration"])
        return api_response(True, "Logged out successfully.", status.HTTP_200_OK)


class SetAccountTypeView(APIView):
    """
    New users call this after OTP verification to choose Personal vs Business.
    One-time: once a business/personal profile exists, this endpoint rejects changes.
    """

    def post(self, request):
        account_type = request.data.get("account_type", "").strip()
        if account_type not in (ACCOUNT_PERSONAL, ACCOUNT_BUSINESS):
            return api_response(
                False, "Invalid account type. Must be 'personal' or 'business'.", status.HTTP_400_BAD_REQUEST,
            )

        user = request.user
        has_workspace = Business.objects.filter(staff__user=user, staff__is_active=True).exists()

        if has_workspace:
            # Already set up — just return current state (idempotent)
            businesses = Business.objects.filter(staff__user=user, staff__is_active=True)
            return api_response(
                True, "Account type already set.", status.HTTP_200_OK,
                user=UserSerializer(user).data,
                businesses=BusinessSerializer(businesses, many=True).data,
            )

        # Set the account type
        user.account_type = account_type
        user.save(update_fields=["account_type"])

        if account_type == ACCOUNT_PERSONAL:
            biz = Business.objects.create(owner=user, name="Personal Finance", business_type="personal")
            StaffMember.objects.create(user=user, business=biz, role=StaffMember.ROLE_OWNER)

        businesses = Business.objects.filter(staff__user=user, staff__is_active=True)
        return api_response(
            True, "Account type set.", status.HTTP_200_OK,
            user=UserSerializer(user).data,
            businesses=BusinessSerializer(businesses, many=True).data,
        )


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class BusinessListCreateView(generics.ListCreateAPIView):
    serializer_class = BusinessSerializer

    # Free plan: 2 business profiles. Premium (having at least one Premium
    # business already) unlocks up to 5. Matches the pricing plan limits.
    FREE_LIMIT = 2
    PREMIUM_LIMIT = 5

    def get_queryset(self):
        return Business.objects.filter(staff__user=self.request.user, staff__is_active=True)

    def create(self, request, *args, **kwargs):
        owned = Business.objects.filter(owner=request.user)
        is_premium = owned.filter(plan=Business.PLAN_PREMIUM).exists()
        limit = self.PREMIUM_LIMIT if is_premium else self.FREE_LIMIT
        if owned.count() >= limit:
            plan_name = "Premium" if is_premium else "Free"
            hint = "You've reached the maximum number of business profiles." if is_premium else "Upgrade to Premium to create more."
            return Response(
                {
                    "error": (
                        f"Your {plan_name} plan allows up to {limit} business profile"
                        f"{'s' if limit != 1 else ''}. {hint}"
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        business = serializer.save(owner=self.request.user)
        StaffMember.objects.create(
            user=self.request.user, business=business, role=StaffMember.ROLE_OWNER
        )


class BusinessDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BusinessSerializer

    def get_queryset(self):
        return Business.objects.filter(owner=self.request.user)


class CloseFiscalYearView(APIView):
    """
    Archives the given business and creates a fresh profile with the same
    details, carrying the old business's total cash/bank balance forward as
    the opening balance of a new "Opening Balance" account on the new profile.
    """

    def post(self, request, pk):
        from banking.models import BankAccount

        old_business = Business.objects.filter(id=pk, owner=request.user).first()
        if not old_business:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        if old_business.status == Business.STATUS_ARCHIVED:
            return Response({"error": "This business is already archived."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            carried_balance = sum(
                (acc.balance for acc in old_business.bank_accounts.filter(is_active=True)),
                start=0,
            )

            old_business.status = Business.STATUS_ARCHIVED
            old_business.save(update_fields=["status"])

            new_business = Business.objects.create(
                owner=old_business.owner,
                name=old_business.name,
                business_type=old_business.business_type,
                address=old_business.address,
                phone=old_business.phone,
                email=old_business.email,
                pan_number=old_business.pan_number,
                vat_number=old_business.vat_number,
                currency=old_business.currency,
                fiscal_year_start=old_business.fiscal_year_start,
                plan=old_business.plan,
                status=Business.STATUS_ACTIVE,
            )

            for staff in old_business.staff.filter(is_active=True):
                StaffMember.objects.create(
                    user=staff.user, business=new_business, role=staff.role, permissions=staff.permissions,
                )

            BankAccount.objects.create(
                business=new_business,
                account_name="Opening Balance",
                account_type=BankAccount.TYPE_CASH,
                opening_balance=carried_balance,
            )

        return Response(
            {
                "success": True,
                "message": "Fiscal year closed. A new business profile has been created.",
                "old_business": BusinessSerializer(old_business).data,
                "new_business": BusinessSerializer(new_business).data,
                "carried_balance": float(carried_balance),
            },
            status=status.HTTP_201_CREATED,
        )


class StaffListView(_RequireStaffManagement, generics.ListCreateAPIView):
    serializer_class = StaffMemberSerializer

    # Free plan: 1 staff member beyond the owner. Premium is unlimited.
    FREE_STAFF_LIMIT = 1

    def get_queryset(self):
        bid = self.kwargs["business_id"]
        return StaffMember.objects.filter(business_id=bid, business__owner=self.request.user)

    def post(self, request, *args, **kwargs):
        serializer = InviteStaffSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            bid = kwargs["business_id"]
            business = Business.objects.get(id=bid, owner=request.user)

            non_owner_count = business.staff.filter(is_active=True).exclude(role=StaffMember.ROLE_OWNER).count()
            already_member = business.staff.filter(user__email=data["email"], is_active=True).exists()
            if (
                business.plan != Business.PLAN_PREMIUM
                and not already_member
                and non_owner_count >= self.FREE_STAFF_LIMIT
            ):
                return Response(
                    {
                        "error": (
                            f"Your Free plan allows up to {self.FREE_STAFF_LIMIT} staff member"
                            f"{'s' if self.FREE_STAFF_LIMIT != 1 else ''} besides the owner. "
                            "Upgrade to Premium to invite more."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            # Get or create the invited user (OTP-only, no password)
            user, created = User.objects.get_or_create(
                email=data["email"],
                defaults={"name": data["name"], "account_type": ACCOUNT_BUSINESS},
            )

            member, _ = StaffMember.objects.get_or_create(
                user=user, business=business,
                defaults={"role": data["role"], "permissions": data.get("permissions") or {}},
            )
            if not _:
                member.role = data["role"]
                member.permissions = data.get("permissions") or {}
                member.is_active = True
                member.save()

            return Response(StaffMemberSerializer(member).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class StaffDetailView(_RequireStaffManagement, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = StaffMemberSerializer

    def get_queryset(self):
        bid = self.kwargs["business_id"]
        return StaffMember.objects.filter(business_id=bid, business__owner=self.request.user)


class StaffActivityView(APIView):
    def get(self, request):
        user_id = request.query_params.get("user_id")

        login_qs = LoginActivity.objects.filter(user=request.user)
        if user_id and request.user.is_platform_admin:
            login_qs = LoginActivity.objects.filter(user_id=user_id)

        data = []
        for la in login_qs[:50]:
            data.append({
                "id": la.id,
                "timestamp": la.timestamp,
                "logout_time": getattr(la, "logout_time", None),
                "session_duration": str(la.session_duration) if getattr(la, "session_duration", None) else None,
                "ip_address": la.ip_address,
                "success": la.success,
            })
        return Response(data)


# ── Business-scoped staff endpoints (used by Flutter /staff/ calls) ────────────

class BusinessStaffListView(_RequireStaffManagement, generics.ListAPIView):
    """List all staff members for the current business."""
    serializer_class = StaffMemberSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        if not bid:
            return StaffMember.objects.none()
        return StaffMember.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        ).select_related("user").distinct()


class BusinessStaffInviteView(_RequireStaffManagement, APIView):
    """Invite (or add) a staff member to the current business."""

    # Free plan: 1 staff member beyond the owner. Premium is unlimited.
    FREE_STAFF_LIMIT = 1

    def post(self, request):
        business = get_business(request)
        if not business:
            return Response({"error": "Business not found."}, status=status.HTTP_400_BAD_REQUEST)

        email = request.data.get("email", "").strip().lower()
        name = request.data.get("name", "").strip()
        role = request.data.get("role", StaffMember.ROLE_CASHIER)

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        valid_roles = [r for r, _ in StaffMember.ROLE_CHOICES]
        if role not in valid_roles:
            role = StaffMember.ROLE_CASHIER

        non_owner_count = business.staff.filter(is_active=True).exclude(role=StaffMember.ROLE_OWNER).count()
        already_member = business.staff.filter(user__email=email, is_active=True).exists()
        if (
            business.plan != Business.PLAN_PREMIUM
            and not already_member
            and non_owner_count >= self.FREE_STAFF_LIMIT
        ):
            return Response(
                {
                    "error": (
                        f"Your Free plan allows up to {self.FREE_STAFF_LIMIT} staff member"
                        f"{'s' if self.FREE_STAFF_LIMIT != 1 else ''} besides the owner. "
                        "Upgrade to Premium to invite more."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        user, _ = User.objects.get_or_create(
            email=email,
            defaults={"name": name or email.split("@")[0].capitalize(), "account_type": ACCOUNT_BUSINESS},
        )
        if name and not user.name:
            user.name = name
            user.save(update_fields=["name"])

        member, created = StaffMember.objects.get_or_create(
            user=user, business=business,
            defaults={"role": role},
        )
        if not created:
            member.role = role
            member.is_active = True
            member.save(update_fields=["role", "is_active"])

        return Response(StaffMemberSerializer(member).data, status=status.HTTP_201_CREATED)


class BusinessStaffActivityView(APIView):
    """Return login activity for all staff in the current business."""

    def get(self, request):
        bid = get_bid(request)
        if not bid:
            return Response([], status=status.HTTP_200_OK)

        staff_user_ids = StaffMember.objects.filter(
            business_id=bid,
            business__staff__user=request.user,
            business__staff__is_active=True,
        ).values_list("user_id", flat=True).distinct()

        activities = LoginActivity.objects.filter(
            user_id__in=staff_user_ids,
        ).select_related("user").order_by("-timestamp")[:100]

        data = [
            {
                "id": la.id,
                "action": "LOGIN",
                "description": f"{la.user.name or la.user.email} logged in",
                "user_name": la.user.name or la.user.email,
                "timestamp": la.timestamp,
                "ip_address": la.ip_address,
                "success": la.success,
            }
            for la in activities
        ]
        return Response(data)
