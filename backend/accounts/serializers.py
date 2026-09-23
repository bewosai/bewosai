from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email as django_validate_email
from rest_framework import serializers
from bewosai.validators import IMAGE_VALIDATORS
from bewosai.utils import suggest_email_typo_fix
from .models import User, Business, FiscalYear, StaffMember, StaffActivity


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
    my_role = serializers.SerializerMethodField()
    my_permissions = serializers.SerializerMethodField()

    class Meta:
        model = Business
        fields = (
            "id", "name", "business_type", "address", "phone", "email",
            "logo", "pan_number", "vat_number", "currency", "fiscal_year_start", "default_tax_rate",
            "plan", "effective_plan", "status", "subscription_expires", "staff_limit_override",
            "web_trial_enabled", "web_trial_start", "web_trial_end",
            "mobile_trial_enabled", "mobile_trial_start", "mobile_trial_end",
            "owner", "owner_name", "owner_business_limit_override", "staff_count", "created_at",
            "my_role", "my_permissions",
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
        extra_kwargs = {"logo": {"validators": IMAGE_VALIDATORS}}

    def get_staff_count(self, obj):
        return obj.staff.filter(is_active=True).count()

    def _viewer(self):
        """Whoever is looking: the request's user, or the `user` a login response passes in."""
        user = self.context.get("user")
        if user is None:
            request = self.context.get("request")
            user = getattr(request, "user", None)
        return user if user is not None and getattr(user, "is_authenticated", False) else None

    def get_my_role(self, obj):
        """The viewer's role in this business ("OWNER" for its owner), or None."""
        user = self._viewer()
        if user is None:
            return None
        if obj.owner_id == user.id:
            return StaffMember.ROLE_OWNER
        member = obj.staff.filter(user=user, is_active=True).first()
        return member.role if member else None

    def get_my_permissions(self, obj):
        """What the viewer may do here, per module — clients hide what's denied."""
        user = self._viewer()
        if user is None:
            return None
        from bewosai.permissions import permission_matrix
        return permission_matrix(user, obj)

    def validate_status(self, value):
        # SUSPENDED is a Super Admin enforcement action (policy violations,
        # non-payment) — an owner PATCHing their own business must only be
        # able to move between ACTIVE and ARCHIVED (the self-service
        # "delete"/"restore my business" pair). Also blocks changing status
        # at all while currently suspended, or setting status=ACTIVE would
        # let an owner lift their own platform-imposed suspension.
        if self.instance and self.instance.status == Business.STATUS_SUSPENDED:
            raise serializers.ValidationError(
                "This business has been suspended by the platform. Contact support to resolve it."
            )
        if value not in (Business.STATUS_ACTIVE, Business.STATUS_ARCHIVED):
            raise serializers.ValidationError(
                "A business can only be set to active or archived here."
            )
        return value


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
        # business is read-only: nothing legitimately re-parents an existing
        # StaffMember row to a different business through this endpoint —
        # moving someone means remove-then-reinvite, not a field edit. Left
        # writable, a caller with only edit access to their own row (a
        # Manager granted the "staff" module, say) could PATCH their own
        # membership onto a business they have no relationship to at all.
        read_only_fields = ("id", "business", "joined_at", "login_token")

    def validate_role(self, value):
        # OWNER is granted exactly once, at business creation
        # (BusinessListCreateView.perform_create) — never through this
        # endpoint, or anyone with staff-edit access (not necessarily the
        # real owner) could promote themselves or anyone else to full
        # ownership of the business.
        if value == StaffMember.ROLE_OWNER:
            raise serializers.ValidationError("A staff member can't be made an owner here.")
        return value


class InviteStaffSerializer(serializers.Serializer):
    # No email/phone — staff created here have no identity of their own and
    # sign in purely through the login link generated on creation (see
    # StaffMember.login_token / StaffLoginView). Keeps "don't require an
    # email for staff" honest instead of just hiding the field.
    name = serializers.CharField(max_length=150)
    role = serializers.ChoiceField(choices=StaffMember.ROLE_CHOICES)
    permissions = serializers.JSONField(required=False, default=dict)

    def validate_role(self, value):
        # See StaffMemberSerializer.validate_role — a new staff member must
        # never be created as OWNER through the invite endpoint.
        if value == StaffMember.ROLE_OWNER:
            raise serializers.ValidationError("A staff member can't be invited as an owner.")
        return value


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

    # --- Phone-number login/signup temporarily disabled (2026-09-16) ---
    # digits = value.lstrip("+")
    # if not digits.isdigit() or not (7 <= len(digits) <= 15):
    #     raise serializers.ValidationError("Enter a valid email address or phone number.")
    # return value, True
    raise serializers.ValidationError("Enter a valid email address.")


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


class StaffActivitySerializer(serializers.ModelSerializer):
    """One row of the owner-facing "who changed what, and when" log —
    see accounts.views.StaffAuditLogView / accounts.models.StaffActivity."""

    user_name = serializers.CharField(source="user.name", read_only=True, default="")
    user_email = serializers.CharField(source="user.email", read_only=True, default="")

    class Meta:
        model = StaffActivity
        fields = (
            "id", "user", "user_name", "user_email", "action", "module", "description",
            "object_type", "object_id", "object_repr", "old_data", "new_data", "timestamp",
        )
        read_only_fields = fields
