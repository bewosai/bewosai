from rest_framework import serializers
from .models import User, Business, StaffMember


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "email", "name", "phone", "account_type", "is_platform_admin", "is_active", "is_verified", "created_at")
        read_only_fields = ("id", "is_platform_admin", "is_active", "is_verified", "created_at")


class BusinessSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source="owner.name", read_only=True)
    staff_count = serializers.SerializerMethodField()

    class Meta:
        model = Business
        fields = (
            "id", "name", "business_type", "address", "phone", "email",
            "logo", "pan_number", "vat_number", "currency", "fiscal_year_start",
            "plan", "status", "subscription_expires",
            "owner", "owner_name", "staff_count", "created_at",
        )
        # plan / subscription_expires are superadmin-only (see
        # superadmin.BusinessActionView) — a business owner must not be able
        # to self-upgrade by PATCHing their own business.
        read_only_fields = ("id", "owner", "created_at", "plan", "subscription_expires")

    def get_staff_count(self, obj):
        return obj.staff.filter(is_active=True).count()


class StaffMemberSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    user_email = serializers.CharField(source="user.email", read_only=True)

    class Meta:
        model = StaffMember
        fields = ("id", "user", "user_name", "user_email", "business", "role", "permissions", "is_active", "joined_at")
        read_only_fields = ("id", "joined_at")


class InviteStaffSerializer(serializers.Serializer):
    email = serializers.EmailField()
    name = serializers.CharField(max_length=150)
    role = serializers.ChoiceField(choices=StaffMember.ROLE_CHOICES)
    permissions = serializers.JSONField(required=False, default=dict)


class SendOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    is_signup = serializers.BooleanField(default=False)

    def validate_email(self, value):
        return value.strip().lower()


class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.RegexField(r"^\d{6}$", error_messages={"invalid": "OTP must be 6 digits."})
    remember = serializers.BooleanField(default=False)
    name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")

    def validate_email(self, value):
        return value.strip().lower()

    def validate_name(self, value):
        return value.strip()
