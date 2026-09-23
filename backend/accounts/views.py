import logging
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from rest_framework import status, generics, permissions
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from datetime import date, timedelta
from bewosai.email import send_otp_email
from .admin_access import grant_platform_admin_if_listed
# from bewosai.sms import send_otp_sms  # phone login/signup temporarily disabled (2026-09-16)
from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, get_platform, require_feature, require_staff_permission, staff_can
from bewosai.utils import client_ip, get_bid, get_business
from .models import User, Business, FiscalYear, StaffMember, StaffActivity, OTPCode, LoginActivity, ACCOUNT_PERSONAL, ACCOUNT_BUSINESS
from bewosai.pagination import LargePageNumberPagination
from .serializers import (
    UserSerializer, BusinessSerializer, FiscalYearSerializer, StaffMemberSerializer, InviteStaffSerializer,
    SendOTPSerializer, VerifyOTPSerializer, GoogleLoginSerializer, StaffActivitySerializer,
)

logger = logging.getLogger(__name__)


class _RequireStaffManagement:
    """Gated by the Super Admin 'Staff Management' feature switch, and by
    whether the current staff member has been granted the 'staff_management'
    module themselves — a non-owner staff member without it can't invite,
    edit, or remove other staff even if they're otherwise a Manager."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("staff_management"), require_staff_permission("staff")]


def api_response(success, message, status_code, **extra):
    return Response({"success": success, "message": message, **extra}, status=status_code)


# Phone-number login/signup temporarily disabled (2026-09-16) — kept
# commented out (not deleted) so it can be restored later.
# def _nepal_local_number(identifier):
#     """
#     Sparrow SMS only delivers to bare 10-digit Nepali mobile numbers.
#     Returns that 10-digit string for a +977 (or country-code-less, assumed
#     domestic) number, or None if `identifier` isn't a Nepal number — in
#     which case the caller falls back to emailing the code instead, since no
#     SMS gateway on file can reach it.
#     """
#     digits = identifier.lstrip("+")
#     if digits.startswith("977") and len(digits) == 13:
#         digits = digits[3:]
#     if len(digits) == 10 and digits.isdigit():
#         return digits
#     return None


def _login_platform(request):
    """'app' for the Flutter app, 'web' for everything else (the website)."""
    return LoginActivity.PLATFORM_APP if get_platform(request) == "mobile" else LoginActivity.PLATFORM_WEB


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

        identifier = serializer.validated_data["identifier"]
        is_signup = serializer.validated_data["is_signup"]

        # --- Phone-number login/signup temporarily disabled (2026-09-16) ---
        # `validate_login_identifier` (serializers.py) now only accepts
        # emails, so `identifier` is always an email here. The phone branch
        # below is kept commented out (not deleted) so it can be restored
        # later — ask before re-enabling.
        #
        # is_phone = "@" not in identifier
        # via_phone_display = None
        # nepal_local = None
        # fallback_email = None
        #
        # if is_phone:
        #     existing = User.objects.filter(phone=identifier).first()
        #     # Sparrow SMS (our gateway) only delivers to Nepali numbers — for
        #     # anything else the code has to go out over email instead.
        #     nepal_local = _nepal_local_number(identifier)
        #
        #     if is_signup:
        #         if existing:
        #             return api_response(
        #                 False, "This phone number is already registered. Please sign in instead.",
        #                 status.HTTP_400_BAD_REQUEST, user_exists=True,
        #             )
        #         if not nepal_local:
        #             # A brand-new account has no email on file yet to fall
        #             # back to, so phone sign-up only works for the one
        #             # gateway we actually have (Nepal numbers via Sparrow).
        #             return api_response(
        #                 False,
        #                 "Signing up with a phone number is only available for Nepal (+977) numbers right now — please use your email instead.",
        #                 status.HTTP_400_BAD_REQUEST,
        #             )
        #     else:
        #         if not existing:
        #             return api_response(False, "No account found with that phone number.", status.HTTP_404_NOT_FOUND)
        #         # Existing account on a non-Nepal number: fall back to
        #         # whichever email address it already has on file.
        #         if not nepal_local:
        #             if not existing.email:
        #                 return api_response(
        #                     False, "This account has no email on file to send a code to — SMS delivery isn't available for this number.",
        #                     status.HTTP_400_BAD_REQUEST,
        #                 )
        #             fallback_email = existing.email
        #             via_phone_display = mask_email(fallback_email)
        # else:
        #     existing = User.objects.filter(email=identifier).first()
        #     if is_signup and existing:
        #         return api_response(
        #             False, "This email is already registered. Please sign in instead.",
        #             status.HTTP_400_BAD_REQUEST, user_exists=True,
        #         )

        existing = User.objects.filter(email=identifier).first()

        # Reject explicit sign-up attempts for already-registered emails
        if is_signup and existing:
            return api_response(
                False, "This email is already registered. Please sign in instead.",
                status.HTTP_400_BAD_REQUEST, user_exists=True,
            )

        wait = OTPCode.seconds_until_resend(identifier)
        if wait > 0:
            return api_response(
                False, f"Please wait {wait}s before requesting another code.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )

        if OTPCode.sends_in_last_hour(identifier) >= OTPCode.MAX_SENDS_PER_HOUR:
            return api_response(
                False,
                "Too many codes have been requested for this email. Please try again in an hour.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )

        account_type = existing.account_type if existing else ACCOUNT_BUSINESS
        otp, code = OTPCode.generate(identifier, account_type)

        # Send synchronously and report the real outcome. This used to fire
        # on a background thread so the request returned instantly, but that
        # meant an SMTP/SendGrid failure was only ever visible in the server
        # log — the client always got "success": true even when no email
        # ever went out, which made real delivery failures undebuggable from
        # the app. The extra second or two of latency is worth the honesty.
        sent = send_otp_email(identifier, code)
        fail_message = "Couldn't send the verification email right now. Please try again in a moment."

        if not sent:
            logger.error("Failed to send OTP via email to %s", identifier)
            otp.delete()
            return api_response(False, fail_message, status.HTTP_502_BAD_GATEWAY)

        logger.info("OTP sent for %s (new_account=%s)", identifier, existing is None)

        message = f"OTP sent to {identifier}. Valid for 10 minutes."
        return api_response(
            True, message, status.HTTP_200_OK,
            user_exists=existing is not None,
        )


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "otp_verify"

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(False, _first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)

        identifier = serializer.validated_data["identifier"]
        code = serializer.validated_data["code"]
        remember = serializer.validated_data["remember"]
        name = serializer.validated_data["name"]
        # is_phone = "@" not in identifier  # phone login/signup temporarily disabled (2026-09-16) — identifier is always an email now

        otp, error_code = OTPCode.verify_and_consume(identifier, code)

        if error_code == "too_many_attempts":
            logger.warning("OTP locked out for %s after too many attempts", identifier)
            return api_response(
                False, "Too many incorrect attempts. Please request a new code.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )
        if error_code == "expired":
            logger.warning("Expired OTP attempt for %s", identifier)
            return api_response(False, "This code has expired. Please request a new one.", status.HTTP_400_BAD_REQUEST)
        if error_code:
            logger.warning("Invalid OTP attempt for %s", identifier)
            return api_response(False, "Incorrect code. Please check and try again.", status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # Phone login/signup temporarily disabled (2026-09-16) — identifier
                # is always an email now; the phone lookup/create branch below is
                # kept commented out (not deleted) for easy restore.
                # if is_phone:
                #     user = User.objects.filter(phone=identifier).first()
                # else:
                user = User.objects.filter(email=identifier).first()
                is_new = user is None
                if is_new:
                    # account_type is a placeholder here; the user picks it via set-account-type
                    # if is_phone:
                    #     user = User.objects.create_user(
                    #         phone=identifier,
                    #         name=name,
                    #         account_type=ACCOUNT_BUSINESS,
                    #         is_verified=True,
                    #     )
                    # else:
                    user = User.objects.create_user(
                        email=identifier,
                        name=name or identifier.split("@")[0].capitalize(),
                        account_type=ACCOUNT_BUSINESS,
                        is_verified=True,
                    )

                user.last_login_at = timezone.now()
                user.is_verified = True
                user.save(update_fields=["last_login_at", "is_verified"])
                grant_platform_admin_if_listed(user)

                LoginActivity.objects.create(
                    user=user,
                    ip_address=client_ip(request),
                    user_agent=request.META.get("HTTP_USER_AGENT", ""),
                    platform=_login_platform(request),
                )
        except Exception:
            # The code was already marked used above. If saving the login then fails
            # (a server-side fault, not the user's), give the code back so they can
            # retry it — otherwise a crash here burns a correct code and the retry
            # is told "Incorrect code".
            OTPCode.objects.filter(pk=otp.pk).update(is_used=False)
            raise

        logger.info("User %s logged in via OTP (new_user=%s)", identifier, is_new)

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
            grant_platform_admin_if_listed(user)

            LoginActivity.objects.create(
                user=user,
                ip_address=client_ip(request),
                user_agent=request.META.get("HTTP_USER_AGENT", ""),
                platform=_login_platform(request),
            )

        logger.info("User %s logged in via Google (new_user=%s)", email, is_new)

        return _login_response(user, is_new, remember)


def _login_response(user, is_new, remember):
    refresh = RefreshToken.for_user(user)
    if remember:
        refresh.set_exp(lifetime=timedelta(days=30))
        refresh.access_token.set_exp(lifetime=timedelta(days=30))

    # Match BusinessListCreateView.get_queryset so a business shows up
    # identically on login as it does in the web/app business switcher —
    # this used to filter to status="ACTIVE" only, which meant a suspended
    # or archived business (still visible everywhere else) would silently
    # vanish from the app right after a fresh email/Google login.
    businesses = Business.objects.filter(staff__user=user, staff__is_active=True)

    return api_response(
        True, "Login successful.", status.HTTP_200_OK,
        access=str(refresh.access_token),
        refresh=str(refresh),
        user=UserSerializer(user).data,
        is_new_user=is_new,
        # New user needs to select their profile type (personal vs business)
        needs_profile_setup=is_new,
        businesses=BusinessSerializer(businesses, many=True, context={"user": user}).data,
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
                businesses=BusinessSerializer(businesses, many=True, context={"user": user}).data,
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
            businesses=BusinessSerializer(businesses, many=True, context={"user": user}).data,
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
        # PremiumPlus (from a coupon/referral reward — see billing app) has
        # no cap at all; Premium (bought/licensed, effective_plan on *any*
        # owned business) unlocks the higher fixed limit; otherwise Free.
        effective_plans = {b.effective_plan for b in owned}
        is_unlimited = Business.PLAN_PREMIUMPLUS in effective_plans
        is_premium = is_unlimited or Business.PLAN_PREMIUM in effective_plans
        plan_limit = self.PREMIUM_LIMIT if is_premium else self.FREE_LIMIT
        # A platform admin can raise (or lower) this per-user via
        # superadmin.UserActionView's "set_business_limit" action.
        limit = request.user.business_limit_override if request.user.business_limit_override is not None else plan_limit
        if not is_unlimited and owned.count() >= limit:
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
        from inventory.defaults import seed_default_units
        from billing.services import process_referral

        business = serializer.save(owner=self.request.user)
        StaffMember.objects.create(
            user=self.request.user, business=business, role=StaffMember.ROLE_OWNER
        )
        # Common units (Piece, Dozen, Kilogram, ...) so there's something to
        # pick from before the business has created any of their own — see
        # inventory.defaults for the full list and the conversions used.
        seed_default_units(business)

        # Refer & Earn — an optional code entered at business-creation time.
        # Silently ignored if blank/invalid rather than blocking signup over
        # a typo'd code; process_referral runs its own anti-abuse checks
        # (self-referral, already-claimed, rate limit) and always leaves a
        # Referral audit row behind either way.
        referral_code = (self.request.data.get("referral_code") or "").strip().upper()
        if referral_code:
            referrer = Business.objects.filter(referral_code=referral_code).exclude(pk=business.pk).first()
            if referrer:
                business.referred_by = referrer
                business.save(update_fields=["referred_by"])
                process_referral(new_business=business, referrer_business=referrer)


class BusinessDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BusinessSerializer

    def get_queryset(self):
        return Business.objects.filter(owner=self.request.user)


def _fiscal_year_bounds(business, today=None):
    """The [start_date, end_date] of the fiscal year covering (or most
    recently ended relative to) `today`, derived from Business.fiscal_year_start
    ("MM-DD"). E.g. fiscal_year_start="07-16" and today=2026-03-01 gives
    (2025-07-16, 2026-07-15) — the year currently in progress."""
    today = today or timezone.localdate()
    fy_month, fy_day = (int(p) for p in business.fiscal_year_start.split("-"))
    this_years_start = date(today.year, fy_month, fy_day)
    start = this_years_start if today >= this_years_start else date(today.year - 1, fy_month, fy_day)
    next_start = date(start.year + 1, fy_month, fy_day)
    end = next_start - timedelta(days=1)
    return start, end


class CloseFiscalYearView(APIView):
    """
    Marks the business's current fiscal year (per Business.fiscal_year_start)
    as closed, in place — no cloning, no archiving. Every Sale/Purchase/
    Expense/etc. stays exactly where it is; this just records that the
    period is closed. Phase 1 of the fiscal-year lock system — nothing yet
    enforces read-only access to records inside a closed period (Phase 2).
    """

    def post(self, request, pk):
        business = Business.objects.filter(id=pk, owner=request.user).first()
        if not business:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        if business.status == Business.STATUS_ARCHIVED:
            return Response({"error": "This business is archived."}, status=status.HTTP_400_BAD_REQUEST)

        start, end = _fiscal_year_bounds(business)
        if FiscalYear.objects.filter(business=business, start_date=start, end_date=end).exists():
            return Response({"error": "This fiscal year has already been closed."}, status=status.HTTP_400_BAD_REQUEST)

        label = f"{start.year}/{str(end.year)[2:]}" if start.year != end.year else str(start.year)
        fiscal_year = FiscalYear.objects.create(
            business=business, start_date=start, end_date=end, label=label,
            status=FiscalYear.STATUS_CLOSED, closed_by=request.user,
        )

        return Response(
            {
                "success": True,
                "message": f"Fiscal year {label} closed.",
                "fiscal_year": FiscalYearSerializer(fiscal_year).data,
            },
            status=status.HTTP_201_CREATED,
        )


class FiscalYearListView(generics.ListAPIView):
    """Past closed fiscal years for a business — read-only, shown in
    Settings so a closed year stays visible/searchable, just not editable."""
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        return FiscalYear.objects.filter(
            business_id=self.kwargs["pk"],
            business__owner=self.request.user,
        )


def _staff_managed_business(request, bid, method):
    """
    Business for `bid` if `request.user` may manage its staff for this
    request's action (owner, or granted the 'staff' module for that
    specific business) — checked against `bid` from the URL rather than
    get_business(request)'s "current business", since those can differ for
    a user who's staff on more than one business. Returns None (caller
    should 404) if the business doesn't exist or access isn't granted —
    deliberately not distinguishing the two, so this can't be used to probe
    which business IDs exist.
    """
    business = Business.objects.filter(id=bid).first()
    if not business or not staff_can(request.user, business, "staff", method):
        return None
    return business


def _staff_limit_error(business, exclude_member=None):
    """
    A 403 Response if `business` has no free staff slot (beyond the owner), else
    None. `exclude_member` is left out of the count — used when re-activating
    an existing member, who is about to take a slot rather than add a second one.
    """
    others = business.staff.filter(is_active=True).exclude(role=StaffMember.ROLE_OWNER)
    if exclude_member is not None:
        others = others.exclude(pk=exclude_member.pk)
    staff_limit = business.staff_limit_override if business.staff_limit_override is not None else plan_staff_limit(business.effective_plan)
    if others.count() < staff_limit:
        return None
    plan_name = plan_display_name(business.effective_plan)
    return Response(
        {
            "error": (
                f"Your {plan_name} plan allows up to {staff_limit} staff member"
                f"{'s' if staff_limit != 1 else ''} besides the owner."
            )
        },
        status=status.HTTP_403_FORBIDDEN,
    )


# Staff members allowed beyond the owner, per business, by plan — a platform
# admin can raise or lower this for one specific business via
# superadmin.BusinessActionView's "set_staff_limit" action, which always wins
# over the plan default below.
STAFF_LIMIT_BY_PLAN = {
    Business.PLAN_FREE: 1,
    Business.PLAN_PREMIUM: 3,
    Business.PLAN_PREMIUMPLUS: 5,
}


def plan_staff_limit(effective_plan):
    return STAFF_LIMIT_BY_PLAN.get(effective_plan, STAFF_LIMIT_BY_PLAN[Business.PLAN_FREE])


def plan_display_name(effective_plan):
    return {
        Business.PLAN_FREE: "Free", Business.PLAN_PREMIUM: "Premium", Business.PLAN_PREMIUMPLUS: "Premium Plus",
    }.get(effective_plan, effective_plan)


class StaffListView(_RequireStaffManagement, generics.ListCreateAPIView):
    serializer_class = StaffMemberSerializer

    def get_queryset(self):
        bid = self.kwargs["business_id"]
        if not _staff_managed_business(self.request, bid, self.request.method):
            return StaffMember.objects.none()
        return StaffMember.objects.filter(business_id=bid)

    def post(self, request, *args, **kwargs):
        serializer = InviteStaffSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            bid = kwargs["business_id"]
            business = _staff_managed_business(request, bid, request.method)
            if not business:
                return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

            limit_error = _staff_limit_error(business)
            if limit_error is not None:
                return limit_error

            # A link-based staff member has no email/phone of their own — no
            # existing account to match against, so every invite creates a
            # brand new placeholder User. They authenticate purely through
            # the login link (StaffMember.login_token / StaffLoginView),
            # never via OTP, hence the unusable password + allow_no_identity.
            user = User.objects.create_user(
                name=data["name"], account_type=ACCOUNT_BUSINESS, is_verified=True,
                allow_no_identity=True,
            )
            member = StaffMember.objects.create(
                user=user, business=business,
                role=data["role"], permissions=data.get("permissions") or {},
                login_token=StaffMember.new_login_token(),
            )

            return Response(StaffMemberSerializer(member).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class StaffDetailView(_RequireStaffManagement, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = StaffMemberSerializer

    def get_queryset(self):
        bid = self.kwargs["business_id"]
        if not _staff_managed_business(self.request, bid, self.request.method):
            return StaffMember.objects.none()
        return StaffMember.objects.filter(business_id=bid)

    @staticmethod
    def _guard_owner(member):
        # The owner's membership is what lists the business for them at all —
        # deleting or deactivating it (even by mistake, or by a manager who was
        # granted staff access) would lock the owner out of their own business.
        if member.role == StaffMember.ROLE_OWNER or member.user_id == member.business.owner_id:
            raise ValidationError({"error": "The business owner's access can't be changed or removed."})

    def perform_update(self, serializer):
        member = serializer.instance
        self._guard_owner(member)
        # Switching someone back on takes a staff slot, so it's subject to the
        # same plan limit as inviting a new member.
        if serializer.validated_data.get("is_active") and not member.is_active:
            limit_error = _staff_limit_error(member.business, exclude_member=member)
            if limit_error is not None:
                raise PermissionDenied(limit_error.data["error"])
        serializer.save()

    def perform_destroy(self, instance):
        self._guard_owner(instance)
        instance.delete()


class StaffRegenerateLinkView(_RequireStaffManagement, APIView):
    """
    Issues a fresh login_token for a staff member, instantly invalidating
    whatever link was out there before — the "I think this link leaked,
    kill it" button, and also how an owner retroactively creates a link for
    staff invited before this feature (or before they had one at all).
    """

    def post(self, request, business_id, pk):
        if not _staff_managed_business(request, business_id, request.method):
            return api_response(False, "Staff member not found.", status.HTTP_404_NOT_FOUND)
        member = StaffMember.objects.filter(pk=pk, business_id=business_id).first()
        if not member:
            return api_response(False, "Staff member not found.", status.HTTP_404_NOT_FOUND)
        if member.role == StaffMember.ROLE_OWNER:
            return api_response(False, "The business owner doesn't use a login link.", status.HTTP_400_BAD_REQUEST)

        member.regenerate_login_token()
        return Response(StaffMemberSerializer(member).data, status=status.HTTP_200_OK)


class StaffLoginView(APIView):
    """
    Exchanges a staff member's login-link token for a JWT pair — the
    passwordless "click this link to open the app as this staff member"
    flow (see StaffMember.login_token). No email/OTP involved: the token
    itself, generated when the owner created (or last regenerated) the
    staff member, is the sole credential. Treat it like a bearer password —
    anyone holding the URL can log in as that staff member until the owner
    regenerates it from Staff management.
    """

    permission_classes = [permissions.AllowAny]
    throttle_scope = "otp_verify"

    def post(self, request):
        token = (request.data.get("token") or "").strip()
        if not token:
            return api_response(False, "Missing login link.", status.HTTP_400_BAD_REQUEST)

        staff = StaffMember.objects.filter(login_token=token).select_related("user", "business").first()
        if not staff or not staff.is_active:
            return api_response(False, "This login link is invalid or has been revoked.", status.HTTP_404_NOT_FOUND)
        if staff.business.status != Business.STATUS_ACTIVE:
            return api_response(False, "This business account is no longer active.", status.HTTP_403_FORBIDDEN)

        user = staff.user
        user.last_login_at = timezone.now()
        user.is_verified = True
        user.save(update_fields=["last_login_at", "is_verified"])

        LoginActivity.objects.create(
            user=user,
            ip_address=client_ip(request),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
            platform=_login_platform(request),
        )

        logger.info("Staff member (user %s) logged in via login link", user.id)
        # remember=True: a link-only account has no OTP/email fallback to
        # re-authenticate with, so the session needs to actually last —
        # same long-lived token lifetime the "Keep me signed in" checkbox
        # gives everyone else.
        return _login_response(user, is_new=False, remember=True)


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

    def post(self, request):
        business = get_business(request)
        if not business:
            return Response({"error": "Business not found."}, status=status.HTTP_400_BAD_REQUEST)

        email = request.data.get("email", "").strip().lower()
        name = request.data.get("name", "").strip()
        role = request.data.get("role", StaffMember.ROLE_CASHIER)
        permissions = request.data.get("permissions")
        if not isinstance(permissions, dict):
            permissions = {}

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        valid_roles = [r for r, _ in StaffMember.ROLE_CHOICES]
        if role not in valid_roles:
            role = StaffMember.ROLE_CASHIER

        non_owner_count = business.staff.filter(is_active=True).exclude(role=StaffMember.ROLE_OWNER).count()
        already_member = business.staff.filter(user__email=email, is_active=True).exists()
        staff_limit = business.staff_limit_override if business.staff_limit_override is not None else plan_staff_limit(business.effective_plan)
        if not already_member and non_owner_count >= staff_limit:
            plan_name = plan_display_name(business.effective_plan)
            return Response(
                {
                    "error": (
                        f"Your {plan_name} plan allows up to {staff_limit} staff member"
                        f"{'s' if staff_limit != 1 else ''} besides the owner."
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
            defaults={"role": role, "permissions": permissions},
        )
        if not created:
            member.role = role
            member.is_active = True
            member.permissions = permissions
            member.save(update_fields=["role", "is_active", "permissions"])

        return Response(StaffMemberSerializer(member).data, status=status.HTTP_201_CREATED)


class BusinessStaffActivityView(APIView):
    """Return login activity for all staff in the current business."""

    def get(self, request):
        bid = get_bid(request)
        if not bid:
            return Response([], status=status.HTTP_200_OK)
        # Other staff members' sign-in times, devices and IPs — for the owner, or
        # someone the owner gave the "staff" module to; not every cashier.
        if not _staff_managed_business(request, bid, "GET"):
            return Response({"error": "Your account doesn't have access to this."}, status=status.HTTP_403_FORBIDDEN)

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


class StaffAuditLogView(generics.ListAPIView):
    """
    The owner-facing "who changed what, and when" log: every Sale, Purchase,
    Expense, Quotation, Product, Party, PartyPayment, BankAccount and
    BankTransaction created, edited (with old -> new values) or deleted in
    this business — populated automatically by superadmin.signals, not by
    this view. Same access rule as BusinessStaffActivityView: the owner, or
    a staff member granted the "staff" module — not every cashier's business.

    Filters (all optional, combine with AND): ?staff=<user id>, ?module=sales,
    ?action=CREATE|UPDATE|DELETE, ?date_from=YYYY-MM-DD, ?date_to=YYYY-MM-DD.
    """
    serializer_class = StaffActivitySerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        bid = get_bid(self.request)
        if not bid or not _staff_managed_business(self.request, bid, "GET"):
            return StaffActivity.objects.none()
        qs = StaffActivity.objects.filter(business_id=bid).select_related("user")

        staff_id = self.request.query_params.get("staff")
        if staff_id:
            qs = qs.filter(user_id=staff_id)
        module = self.request.query_params.get("module")
        if module:
            qs = qs.filter(module=module)
        action = self.request.query_params.get("action")
        if action:
            qs = qs.filter(action=action.upper())
        date_from = self.request.query_params.get("date_from")
        if date_from:
            qs = qs.filter(timestamp__date__gte=date_from)
        date_to = self.request.query_params.get("date_to")
        if date_to:
            qs = qs.filter(timestamp__date__lte=date_to)
        return qs

    def get(self, request, *args, **kwargs):
        bid = get_bid(request)
        if bid and not _staff_managed_business(request, bid, "GET"):
            return Response({"error": "Your account doesn't have access to this."}, status=status.HTTP_403_FORBIDDEN)
        return super().get(request, *args, **kwargs)


# ── Licensing ────────────────────────────────────────────────────────────────

def _license_payload(license_obj):
    if not license_obj:
        return None
    return {
        "id": license_obj.id,
        "code": license_obj.code,
        "plan": license_obj.plan,
        "duration_type": license_obj.duration_type,
        "duration_days": license_obj.duration_days,
        "start_date": license_obj.start_date,
        "expiry_date": license_obj.expiry_date,
        "status": license_obj.status,
        "activated_at": license_obj.activated_at,
    }


class LicenseMeView(APIView):
    """
    Trial/license status for the current business. The frontend calls this
    right after login/business-select to decide Dashboard vs the License
    Required screen — exempted from HasActiveSubscription (see
    bewosai.permissions) so a locked-out business can still find out *why*.
    """

    def get(self, request):
        business = get_business(request)
        if not business:
            return api_response(False, "No business selected.", status.HTTP_400_BAD_REQUEST)

        platform = get_platform(request)
        return Response({
            "success": True,
            # True if any of: grandfathered, the automatic trial, an active
            # license, or a Super-Admin-granted trial for this platform —
            # see Business.has_access. Kept under the same key so existing
            # clients don't need to change what they check.
            "has_active_subscription": business.has_access(platform),
            "is_grandfathered": business.is_grandfathered,
            "is_trial_active": business.is_trial_active,
            "trial_expiry_date": business.trial_expiry_date,
            "platform_trial_active": business.has_active_platform_trial(platform),
            "web_trial_enabled": business.web_trial_enabled,
            "web_trial_start": business.web_trial_start,
            "web_trial_end": business.web_trial_end,
            "mobile_trial_enabled": business.mobile_trial_enabled,
            "mobile_trial_start": business.mobile_trial_start,
            "mobile_trial_end": business.mobile_trial_end,
            "license": _license_payload(business.active_license),
        })


class LicenseActivateView(APIView):
    """
    POST {"code": "A7K9P"} — activates a license Super Admin generated for
    the current business. Also exempted from HasActiveSubscription, since a
    business with no active subscription is exactly who needs to call this.
    """

    def post(self, request):
        business = get_business(request)
        if not business:
            return api_response(False, "No business selected.", status.HTTP_400_BAD_REQUEST)
        if business.owner_id != request.user.id:
            return api_response(False, "Only the business owner can activate a license.", status.HTTP_403_FORBIDDEN)

        code = (request.data.get("code") or "").strip().upper()
        if not code:
            return api_response(False, "Enter a license code.", status.HTTP_400_BAD_REQUEST)

        from superadmin.models import License, LicenseAuditLog

        license_obj = License.objects.filter(code=code).first()
        if license_obj is None:
            return api_response(False, "Invalid license code.", status.HTTP_404_NOT_FOUND)

        if license_obj.business_id != business.id:
            return api_response(
                False, "This license code is not assigned to this account.", status.HTTP_403_FORBIDDEN,
            )

        if license_obj.status == License.STATUS_REVOKED:
            return api_response(False, "This license has been revoked.", status.HTTP_400_BAD_REQUEST)

        if timezone.localdate() >= license_obj.expiry_date:
            if license_obj.status != License.STATUS_EXPIRED:
                license_obj.status = License.STATUS_EXPIRED
                license_obj.save(update_fields=["status"])
            return api_response(False, "This license has expired.", status.HTTP_400_BAD_REQUEST)

        if license_obj.status != License.STATUS_ACTIVE:
            license_obj.status = License.STATUS_ACTIVE
            license_obj.activated_at = timezone.now()
            license_obj.save(update_fields=["status", "activated_at"])
            LicenseAuditLog.objects.create(
                actor=request.user, action=LicenseAuditLog.ACTION_ACTIVATED,
                business=business, license=license_obj,
                new_value=f"active until {license_obj.expiry_date}",
            )

        # Deliberately outside the "just transitioned to active" branch above
        # and re-checked on every call, not just the first: a business whose
        # license was activated before this sync existed would otherwise stay
        # permanently stuck on the Free plan, since re-submitting the same
        # already-ACTIVE code would skip the block entirely. Making this
        # idempotent means simply re-entering the code fixes it — no admin
        # or database intervention needed.
        if license_obj.plan == Business.PLAN_PREMIUM and business.plan != Business.PLAN_PREMIUM:
            business.plan = Business.PLAN_PREMIUM
            business.save(update_fields=["plan"])

        return Response({
            "success": True,
            "message": f"License activated successfully. Premium access is active until {license_obj.expiry_date}.",
            "license": _license_payload(license_obj),
        })
