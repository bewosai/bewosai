from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email as django_validate_email
from rest_framework import serializers
from bewosai.utils import suggest_email_typo_fix
from .models import User, Business, StaffMember


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "email", "name", "phone", "account_type", "is_platform_admin", "is_active", "is_verified", "created_at")
        read_only_fields = ("id", "is_platform_admin", "is_active", "is_verified", "created_at")

    def validate_phone(self, value):
        value = (value or "").strip()
        if not value:
            # phone is unique=True; storing "" for everyone who leaves it
            # blank would make the *second* such save collide against the
            # first with a confusing "already exists" error. None is exempt
            # from the unique constraint, "" is not.
            return None
        digits = value.lstrip("+")
        if not digits.isdigit() or not (7 <= len(digits) <= 15):
            raise serializers.ValidationError("Enter a valid phone number (7-15 digits).")
        return value


class BusinessSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source="owner.name", read_only=True)
    staff_count = serializers.SerializerMethodField()

    class Meta:
        model = Business
        fields = (
            "id", "name", "business_type", "address", "phone", "email",
            "logo", "pan_number", "vat_number", "currency", "fiscal_year_start", "default_tax_rate",
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


def validate_login_identifier(value):
    """
    Shared by Send/VerifyOTPSerializer — the single "email or phone" field
    both the web and mobile login screens now show. Returns
    (identifier, is_phone); raises ValidationError for anything that's
    neither a plausible email nor a plausible phone number.
    """
    value = value.strip()
    if "@" in value:
        email = value.lower()
        try:
            django_validate_email(email)
        except DjangoValidationError:
            raise serializers.ValidationError("Enter a valid email address.")
        fix = suggest_email_typo_fix(email)
        if fix:
            raise serializers.ValidationError(
                f"Did you mean {fix}? \"{email.rpartition('@')[2]}\" isn't a real "
                f"{fix.rpartition('@')[2]} address, so the code would never arrive."
            )
        return email, False

    digits = value.lstrip("+")
    if not digits.isdigit() or not (7 <= len(digits) <= 15):
        raise serializers.ValidationError("Enter a valid email address or phone number.")
    return value, True


class SendOTPSerializer(serializers.Serializer):
    identifier = serializers.CharField(max_length=254)
    is_signup = serializers.BooleanField(default=False)

    def validate_identifier(self, value):
        identifier, _ = validate_login_identifier(value)
        return identifier


class VerifyOTPSerializer(serializers.Serializer):
    identifier = serializers.CharField(max_length=254)
    code = serializers.RegexField(r"^\d{6}$", error_messages={"invalid": "OTP must be 6 digits."})
    remember = serializers.BooleanField(default=False)
    name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")

    def validate_identifier(self, value):
        identifier, _ = validate_login_identifier(value)
        return identifier

    def validate_name(self, value):
        return value.strip()


class GoogleLoginSerializer(serializers.Serializer):
    id_token = serializers.CharField()
    remember = serializers.BooleanField(default=False)
