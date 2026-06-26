from rest_framework import status, generics, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils import timezone
from django.conf import settings
from django.core.mail import send_mail
from datetime import timedelta
from .models import User, Business, StaffMember, OTPCode, LoginActivity, StaffActivity, ACCOUNT_PERSONAL, ACCOUNT_BUSINESS
from .serializers import UserSerializer, BusinessSerializer, StaffMemberSerializer, InviteStaffSerializer


class SendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        # Use existing user's account_type if they exist; default to business for new
        existing = User.objects.filter(email=email).first()
        account_type = existing.account_type if existing else ACCOUNT_BUSINESS

        otp = OTPCode.generate(email, account_type)

        try:
            send_mail(
                subject="Your Bewosy Verification Code",
                message=(
                    f"Your Bewosy OTP: {otp.code}\n\n"
                    "Valid for 10 minutes. Never share this code.\n\n— Bewosy Team"
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=True,
            )
        except Exception:
            pass
        print(f"\n[BEWOSY OTP] Email: {email}  Code: {otp.code}\n")

        response_data = {
            "message": f"OTP sent to {email}. Valid for 10 minutes.",
            # Tell frontend whether this email already has an account
            "user_exists": existing is not None,
        }
        if settings.DEBUG:
            response_data["otp"] = otp.code

        return Response(response_data)


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        code = request.data.get("code", "").strip()
        account_type = request.data.get("account_type", ACCOUNT_BUSINESS)
        remember = request.data.get("remember", False)
        name = request.data.get("name", "").strip()

        if not email or not code:
            return Response({"error": "Email and OTP code are required."}, status=status.HTTP_400_BAD_REQUEST)

        otp = OTPCode.objects.filter(
            email=email, code=code, is_used=False, expires_at__gt=timezone.now()
        ).first()

        if not otp:
            return Response({"error": "Invalid or expired OTP. Please try again."}, status=status.HTTP_400_BAD_REQUEST)

        otp.is_used = True
        otp.save()

        # Get or create user — existing users always keep their stored account_type
        try:
            user = User.objects.get(email=email)
            is_new = False
        except User.DoesNotExist:
            # New user: create with a placeholder account_type; they will choose in next step
            # account_type from request is ignored for new users here (chosen in set-account-type step)
            user = User.objects.create_user(
                email=email,
                name=name or email.split("@")[0].capitalize(),
                account_type=ACCOUNT_BUSINESS,  # placeholder; overwritten by set-account-type
                is_verified=True,
            )
            is_new = True

        user.last_login_at = timezone.now()
        user.is_verified = True
        user.save(update_fields=["last_login_at", "is_verified"])

        LoginActivity.objects.create(
            user=user,
            ip_address=request.META.get("REMOTE_ADDR"),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
        )

        # Generate JWT
        refresh = RefreshToken.for_user(user)
        if remember:
            refresh.set_exp(lifetime=timedelta(days=30))
            refresh.access_token.set_exp(lifetime=timedelta(days=30))

        businesses = Business.objects.filter(staff__user=user, staff__is_active=True, status="ACTIVE")

        return Response({
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
            "is_new_user": is_new,
            # New user needs to select their profile type (personal vs business)
            "needs_profile_setup": is_new,
            "businesses": BusinessSerializer(businesses, many=True).data,
        })


class LogoutView(APIView):
    def post(self, request):
        try:
            RefreshToken(request.data.get("refresh")).blacklist()
        except Exception:
            pass
        # Record logout
        last_login = LoginActivity.objects.filter(user=request.user, logout_time__isnull=True).first()
        if last_login:
            now = timezone.now()
            last_login.logout_time = now
            last_login.session_duration = now - last_login.timestamp
            last_login.save(update_fields=["logout_time", "session_duration"])
        return Response({"message": "Logged out successfully."})


class SetAccountTypeView(APIView):
    """
    New users call this after OTP verification to choose Personal vs Business.
    One-time: once a business/personal profile exists, this endpoint rejects changes.
    """

    def post(self, request):
        account_type = request.data.get("account_type", "").strip()
        if account_type not in (ACCOUNT_PERSONAL, ACCOUNT_BUSINESS):
            return Response({"error": "Invalid account type. Must be 'personal' or 'business'."}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        has_workspace = Business.objects.filter(staff__user=user, staff__is_active=True).exists()

        if has_workspace:
            # Already set up — just return current state (idempotent)
            businesses = Business.objects.filter(staff__user=user, staff__is_active=True)
            return Response({
                "user": UserSerializer(user).data,
                "businesses": BusinessSerializer(businesses, many=True).data,
            })

        # Set the account type
        user.account_type = account_type
        user.save(update_fields=["account_type"])

        if account_type == ACCOUNT_PERSONAL:
            biz = Business.objects.create(owner=user, name="Personal Finance", business_type="personal")
            StaffMember.objects.create(user=user, business=biz, role=StaffMember.ROLE_OWNER)

        businesses = Business.objects.filter(staff__user=user, staff__is_active=True)
        return Response({
            "user": UserSerializer(user).data,
            "businesses": BusinessSerializer(businesses, many=True).data,
        })


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class BusinessListCreateView(generics.ListCreateAPIView):
    serializer_class = BusinessSerializer

    def get_queryset(self):
        return Business.objects.filter(staff__user=self.request.user, staff__is_active=True)

    def perform_create(self, serializer):
        business = serializer.save(owner=self.request.user)
        StaffMember.objects.create(
            user=self.request.user, business=business, role=StaffMember.ROLE_OWNER
        )


class BusinessDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BusinessSerializer

    def get_queryset(self):
        return Business.objects.filter(owner=self.request.user)


class StaffListView(generics.ListCreateAPIView):
    serializer_class = StaffMemberSerializer

    def get_queryset(self):
        bid = self.kwargs["business_id"]
        return StaffMember.objects.filter(business_id=bid, business__owner=self.request.user)

    def post(self, request, *args, **kwargs):
        serializer = InviteStaffSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            bid = kwargs["business_id"]
            business = Business.objects.get(id=bid, owner=request.user)

            # Get or create the invited user (OTP-only, no password)
            user, created = User.objects.get_or_create(
                email=data["email"],
                defaults={"name": data["name"], "account_type": ACCOUNT_BUSINESS},
            )

            member, _ = StaffMember.objects.get_or_create(
                user=user, business=business,
                defaults={"role": data["role"]},
            )
            if not _:
                member.role = data["role"]
                member.is_active = True
                member.save()

            return Response(StaffMemberSerializer(member).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class StaffDetailView(generics.RetrieveUpdateDestroyAPIView):
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
