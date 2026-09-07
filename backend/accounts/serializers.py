from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email as django_validate_email
from rest_framework import serializers
from bewosai.utils import suggest_email_typo_fix
from .models import User, Business, FiscalYear, StaffMember


class UserSerializer(serializers.ModelSerializer):
    # How many business profiles this user owns — Super Admin's user list
    # shows it, matching the existing staff_count pattern on
    # BusinessSerializer (one extra query per row, same trade-off already
    # accepted there).
    business_count = serializers.IntegerField(source="businesses.count", read_only=True)

    class Meta:
        model = User
        fields = ("id", "email", "name", "phone", "account_type", "is_platform_admin", "is_active", "is_verified", "created_at", "business_limit_override", "business_count")
        # business_limit_override is platform-admin-only (set directly on the
        # model by superadmin.UserActionView, bypassing this serializer) —
        # read-only here so a user's own profile PATCH can never self-grant it.
        read_only_fields = ("id", "is_platform_admin", "is_active", "is_verified", "created_at", "business_limit_override")

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
    owner_business_limit_override = serializers.IntegerField(source="owner.business_limit_override", read_only=True)
    # The plan actually in force right now — `plan` alone only reflects a
    # License/superadmin-set tier, not a coupon/referral-granted one (see
    # Business.effective_plan). Both web and mobile's client-side "you're on
    # the Free plan" UX (e.g. the staff-invite limit banner) must read this,
    # not `plan`, or a PremiumPlus-via-coupon business would still see
    # itself as Free-limited even though the backend would actually allow it.
    effective_plan = serializers.CharField(read_only=True)

    class Meta:
        model = Business
        fields = (
            "id", "name", "business_type", "address", "phone", "email",
            "logo", "pan_number", "vat_number", "currency", "fiscal_year_start", "default_tax_rate",
            "plan", "effective_plan", "status", "subscription_expires", "staff_limit_override",
            "web_trial_enabled", "web_trial_start", "web_trial_end",
            "mobile_trial_enabled", "mobile_trial_start", "mobile_trial_end",
            "owner", "owner_name", "owner_business_limit_override", "staff_count", "created_at",
        )
        # plan / subscription_expires / staff_limit_override / the trial
        # fields are superadmin-only (see superadmin.BusinessActionView) — a
        # business owner must not be able to self-upgrade, self-grant more
        # staff, or self-grant a trial by PATCHing their own business.
        read_only_fields = (
            "id", "owner", "created_at", "plan", "subscription_expires", "staff_limit_override",
            "web_trial_enabled", "web_trial_start", "web_trial_end",
            "mobile_trial_enabled", "mobile_trial_start", "mobile_trial_end",
        )

    def get_staff_count(self, obj):
        return obj.staff.filter(is_active=True).count()


class FiscalYearSerializer(serializers.ModelSerializer):
    closed_by_name = serializers.CharField(source="closed_by.name", read_only=True, default="")

    class Meta:
        model = FiscalYear
        fields = ("id", "start_date", "end_date", "label", "status", "closed_by_name", "closed_at")
        read_only_fields = fields


class StaffMemberSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    user_email = serializers.CharField(source="user.email", read_only=True)

    class Meta:
        model = StaffMember
        # login_token is only ever read by whoever can already see this
        # list (the owner, or a manager granted the "staff" module) — same
        # access level that already sees every other staff member's PII
        # here, so surfacing it is not a wider exposure than the endpoint
        # already has.
        fields = ("id", "user", "user_name", "user_email", "business", "role", "permissions", "is_active", "joined_at", "login_token")
        read_only_fields = ("id", "joined_at", "login_token")


class InviteStaffSerializer(serializers.Serializer):
    # No email/phone — staff created here have no identity of their own and
    # sign in purely through the login link generated on creation (see
    # StaffMember.login_token / StaffLoginView). Keeps "don't require an
    # email for staff" honest instead of just hiding the field.
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
