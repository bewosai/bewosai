import secrets
from django.db import models, transaction
from django.contrib.auth.hashers import make_password, check_password
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.utils import timezone
from datetime import date, timedelta


ACCOUNT_PERSONAL = "personal"
ACCOUNT_BUSINESS = "business"
ACCOUNT_TYPE_CHOICES = [(ACCOUNT_PERSONAL, "Personal"), (ACCOUNT_BUSINESS, "Business")]


class UserManager(BaseUserManager):
    def create_user(self, email=None, phone=None, name="", password=None, allow_no_identity=False, **extra_fields):
        # allow_no_identity=True is for staff members created via a login
        # link (see StaffMember.login_token) — they have no email/phone of
        # their own and only ever authenticate through that link, so there's
        # nothing to require here.
        if not email and not phone and not allow_no_identity:
            raise ValueError("Email or phone is required")
        if email:
            email = self.normalize_email(email)
        user = self.model(email=email or None, phone=phone or None, name=name, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, name="", password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_platform_admin", True)
        extra_fields.setdefault("account_type", ACCOUNT_BUSINESS)
        return self.create_user(email=email, name=name, password=password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    # null (not just blank) so multiple phone-only accounts with no email on
    # file don't collide against the unique constraint — same reasoning as
    # `phone` below. A user can sign up with just a phone number now; email
    # stays required only for accounts created via the email/Google flows.
    email = models.EmailField(unique=True, null=True, blank=True)
    name = models.CharField(max_length=150, blank=True)
    # null (not just blank) so multiple accounts with no phone on file don't
    # collide against the unique constraint — only an actually-entered phone
    # number needs to be unique.
    phone = models.CharField(max_length=20, blank=True, null=True, unique=True)
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPE_CHOICES, default=ACCOUNT_BUSINESS)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_platform_admin = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    last_login_at = models.DateTimeField(null=True, blank=True)
    # Platform-admin-only override of BusinessListCreateView's plan-based
    # business-count cap (FREE=2/PREMIUM=5) for this user specifically — set
    # via superadmin.UserActionView's "set_business_limit" action. Null means
    # "use the plan default", never editable by the user themselves.
    business_limit_override = models.PositiveIntegerField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    def __str__(self):
        return self.email or self.phone or f"user #{self.pk}"


class OTPCode(models.Model):
    MAX_ATTEMPTS = 5
    RESEND_COOLDOWN_SECONDS = 60

    # Whatever the user typed on the login/signup screen — an email address
    # or a phone number (with country code). Kept as a plain identifier
    # rather than resolving phone -> account email up front, so a brand-new
    # phone-only signup (no account, no email yet) still has something to
    # key the OTP row on.
    identifier = models.CharField(max_length=254)
    code_hash = models.CharField(max_length=128)
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPE_CHOICES, default=ACCOUNT_BUSINESS)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.identifier} – OTP ({'used' if self.is_used else 'active'})"

    @property
    def is_valid(self):
        return not self.is_used and self.expires_at > timezone.now()

    @classmethod
    def generate(cls, identifier, account_type):
        """Create a new OTP, invalidating any prior unused ones. Returns (otp, plaintext_code)."""
        cls.objects.filter(identifier=identifier, is_used=False).update(is_used=True)
        code = str(secrets.SystemRandom().randint(100000, 999999))
        otp = cls.objects.create(
            identifier=identifier,
            code_hash=make_password(code),
            account_type=account_type,
            expires_at=timezone.now() + timedelta(minutes=10),
        )
        return otp, code

    @classmethod
    def seconds_until_resend(cls, identifier):
        """Seconds the caller must still wait before requesting another OTP, or 0 if allowed now."""
        last = cls.objects.filter(identifier=identifier).order_by("-created_at").first()
        if not last:
            return 0
        elapsed = (timezone.now() - last.created_at).total_seconds()
        remaining = cls.RESEND_COOLDOWN_SECONDS - elapsed
        return max(0, int(remaining))

    @classmethod
    def verify_and_consume(cls, identifier, code):
        """
        Validate `code` for `identifier` and mark it used on success.
        Returns (otp_or_None, error_code) where error_code is one of
        None, "invalid", "expired", "too_many_attempts".
        """
        with transaction.atomic():
            otp = (
                cls.objects.select_for_update()
                .filter(identifier=identifier, is_used=False, expires_at__gt=timezone.now())
                .order_by("-created_at")
                .first()
            )
            if not otp:
                # An unused-but-expired row means the user had a valid code
                # that simply timed out (10 min) rather than typed the wrong
                # digits — worth telling apart since the fix differs (request
                # a new code vs. re-check what you typed). A "Resend" marks
                # the old row is_used=True, so it won't match here either.
                had_unused = cls.objects.filter(identifier=identifier, is_used=False).exists()
                return None, "expired" if had_unused else "invalid"

            if otp.attempts >= cls.MAX_ATTEMPTS:
                otp.is_used = True
                otp.save(update_fields=["is_used"])
                return None, "too_many_attempts"

            if not check_password(code, otp.code_hash):
                otp.attempts += 1
                otp.save(update_fields=["attempts"])
                return None, "invalid"

            otp.is_used = True
            otp.save(update_fields=["is_used"])
            return otp, None


class Business(models.Model):
    PLAN_FREE = "FREE"
    PLAN_PREMIUM = "PREMIUM"
    PLAN_PREMIUMPLUS = "PREMIUMPLUS"
    PLAN_CHOICES = [(PLAN_FREE, "Free"), (PLAN_PREMIUM, "Premium"), (PLAN_PREMIUMPLUS, "Premium Plus")]
    # Ordering used to compare tiers (effective_plan takes the highest of
    # several sources rather than just overwriting `plan`) — index, not the
    # string value, is what makes "PremiumPlus beats Premium beats Free" work.
    _PLAN_ORDER = [PLAN_FREE, PLAN_PREMIUM, PLAN_PREMIUMPLUS]

    STATUS_ACTIVE = "ACTIVE"
    STATUS_SUSPENDED = "SUSPENDED"
    STATUS_ARCHIVED = "ARCHIVED"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_SUSPENDED, "Suspended"),
        (STATUS_ARCHIVED, "Archived"),
    ]

    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="businesses")
    name = models.CharField(max_length=200)
    business_type = models.CharField(max_length=100, blank=True)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    logo = models.ImageField(upload_to="business_logos/", null=True, blank=True)
    # Nepal tax registration
    pan_number = models.CharField(max_length=20, blank=True)
    vat_number = models.CharField(max_length=20, blank=True)
    currency = models.CharField(max_length=5, default="NPR")
    fiscal_year_start = models.CharField(max_length=5, default="07-16", help_text="MM-DD, Nepal fiscal year starts mid-July")
    default_tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=13, help_text="Default VAT % applied to new sales/purchases, e.g. 13")
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES, default=PLAN_FREE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    subscription_expires = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    # Platform-admin-only override of the plan-based staff-count cap
    # (FREE=1/PREMIUM=8) for this business specifically — set via
    # superadmin.BusinessActionView's "set_staff_limit" action. Null means
    # "use the plan default"; never editable by the business owner themselves
    # (see BusinessSerializer.Meta.read_only_fields).
    staff_limit_override = models.PositiveIntegerField(null=True, blank=True)

    # Platform-admin-granted trial window, independent of the automatic
    # TRIAL_DAYS window below and of the license system — set via
    # superadmin.BusinessActionView's "set_trial" action (Super Admin's
    # "Manage Trial"). Split by platform so e.g. a business can be trialing
    # the mobile app without that also unlocking web, or vice versa. Never
    # editable by the business owner themselves (see
    # BusinessSerializer.Meta.read_only_fields).
    web_trial_enabled = models.BooleanField(default=False)
    web_trial_start = models.DateField(null=True, blank=True)
    web_trial_end = models.DateField(null=True, blank=True)
    mobile_trial_enabled = models.BooleanField(default=False)
    mobile_trial_start = models.DateField(null=True, blank=True)
    mobile_trial_end = models.DateField(null=True, blank=True)

    # Refer-and-win — every business gets its own shareable code (see
    # _new_referral_code below); `referred_by` is set at most once, at
    # creation time, and never editable afterward so a referral can't be
    # attached retroactively to game the reward (see billing app for what
    # granting a referral reward actually does).
    referral_code = models.CharField(max_length=10, unique=True, null=True, blank=True, db_index=True)
    referred_by = models.ForeignKey(
        "self", null=True, blank=True, on_delete=models.SET_NULL, related_name="referrals",
    )

    # 120 days for now while the app is new, so people have real room to try
    # it out before needing a license — tighten this once there's an
    # established user base.
    TRIAL_DAYS = 120
    # Businesses created before licensing shipped are grandfathered — their
    # trial would already read as expired since it's computed from
    # created_at, and retroactively locking out every existing business the
    # moment this feature deploys would break the live app for everyone
    # already using it. Only businesses created from this date on are
    # actually subject to trial/license enforcement.
    LICENSING_STARTS = date(2026, 8, 19)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "businesses"
        ordering = ["-created_at"]

    @classmethod
    def _new_referral_code(cls):
        alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ2346789"  # no 0/1/I/O — avoids visual confusion, same alphabet superadmin.License uses
        for _ in range(50):
            code = "".join(secrets.choice(alphabet) for _ in range(8))
            if not cls.objects.filter(referral_code=code).exists():
                return code
        raise RuntimeError("Could not find an unused referral code after 50 attempts.")

    def save(self, *args, **kwargs):
        if not self.referral_code:
            self.referral_code = self._new_referral_code()
        super().save(*args, **kwargs)

    def referral_count(self):
        """How many businesses this one has successfully referred — a live
        count rather than a stored counter, so it can never drift out of
        sync with the actual `referred_by` rows."""
        return Business.objects.filter(referred_by=self).count()

    @property
    def trial_expiry_date(self):
        """Computed from created_at rather than stored — nothing to drift
        out of sync, and every business (including ones created before this
        field existed) gets a well-defined trial window for free."""
        created = self.created_at.date() if self.created_at else timezone.localdate()
        return created + timedelta(days=self.TRIAL_DAYS)

    @property
    def is_trial_active(self):
        return timezone.localdate() < self.trial_expiry_date

    @property
    def active_license(self):
        from superadmin.models import License

        return (
            self.licenses.filter(status=License.STATUS_ACTIVE, expiry_date__gt=timezone.localdate())
            .order_by("-expiry_date")
            .first()
        )

    @property
    def is_grandfathered(self):
        created = self.created_at.date() if self.created_at else timezone.localdate()
        return created < self.LICENSING_STARTS

    @property
    def _active_subscriptions(self):
        """Every still-active billing.Subscription row for this business's
        *owner* — deliberately account-wide (keyed by user, not business),
        so redeeming a coupon on one business benefits every business that
        same person owns, matching how someone thinks of "my plan" rather
        than "this one business's plan." Subscription.user is always the
        redeeming account (see billing.services.apply_coupon /
        _extend_and_grant), so this is safe regardless of which of the
        owner's businesses the entitlement was originally applied under
        (Coupon.used_for_business still records that, for display/audit —
        this just no longer limits who benefits from it).

        Kept as a local import, same as active_license above, since billing
        depends on accounts and not the other way around."""
        from billing.models import Subscription

        return Subscription.objects.filter(
            user_id=self.owner_id, status=Subscription.STATUS_ACTIVE, end_date__gte=timezone.localdate(),
        )

    @property
    def active_referral_subscription(self):
        """The active Subscription row actually responsible for the current
        effective_plan — i.e. the highest-tier one, tie-broken by furthest
        expiry. Deliberately NOT just "whichever active row expires
        latest": a business can hold more than one active Subscription at
        once (e.g. a longer-running Premium plus a shorter, more recent
        PremiumPlus reward), and picking by date alone could surface the
        lower tier and under-report what the business actually has."""
        active = list(self._active_subscriptions)
        if not active:
            return None
        best_plan = max((s.plan for s in active), key=self._PLAN_ORDER.index)
        matching = [s for s in active if s.plan == best_plan]
        return max(matching, key=lambda s: s.end_date)

    @property
    def effective_plan(self):
        """The plan actually in force right now — the higher of the
        License-driven `plan` field (unchanged, still set directly by
        LicenseActivateView/superadmin) and any still-active coupon/referral
        Subscription layered on top. A referral reward or admin coupon can
        only ever raise this, never lower someone who's already paying for
        Premium/PremiumPlus directly."""
        candidates = [self.plan]
        sub = self.active_referral_subscription
        if sub:
            candidates.append(sub.plan)
        return max(candidates, key=self._PLAN_ORDER.index)

    @property
    def has_active_subscription(self):
        """The single source of truth for 'can this business use the app right
        now' — grandfathered, trial window, a currently-active license, or a
        currently-active coupon/referral subscription. Server time only;
        never trust a client-supplied date."""
        return (
            self.is_grandfathered or self.is_trial_active
            or self.active_license is not None or self.active_referral_subscription is not None
        )

    def has_active_platform_trial(self, platform):
        """Whether Super Admin has granted an active trial for this specific
        platform ('web' or 'mobile') via Manage Trial — separate from the
        automatic TRIAL_DAYS window."""
        today = timezone.localdate()
        prefix = "mobile_trial_" if platform == "mobile" else "web_trial_"
        enabled, start, end = (getattr(self, prefix + f) for f in ("enabled", "start", "end"))
        return bool(enabled and start and end and start <= today <= end)

    def has_access(self, platform):
        """Can this business use the app right now on this platform —
        [has_active_subscription] OR an admin-granted platform trial, either
        is sufficient. Use this (not has_active_subscription directly) for
        anything platform-aware, e.g. HasActiveSubscription/LicenseMeView."""
        return self.has_active_subscription or self.has_active_platform_trial(platform)


class FiscalYear(models.Model):
    """
    Marks a date range on a business as closed — Phase 1 of the fiscal-year
    lock system (see the "Fiscal Year Lock + Edit Requests + Audit Log" plan).
    Replaces the old CloseFiscalYearView behavior of archiving the whole
    Business and cloning a new one: closing now just records the period here
    and leaves every Sale/Purchase/Expense/etc. exactly where it is. This
    phase is informational only — nothing yet actually enforces read-only
    access to records inside a CLOSED period (that's Phase 2).
    """
    STATUS_ACTIVE = "ACTIVE"
    STATUS_CLOSED = "CLOSED"
    STATUS_CHOICES = [(STATUS_ACTIVE, "Active"), (STATUS_CLOSED, "Closed")]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="fiscal_years")
    start_date = models.DateField()
    end_date = models.DateField()
    # e.g. "2082/83" — Nepali fiscal years span two Gregorian years, so a
    # plain year number would be ambiguous; computed once at close time from
    # the closing date rather than re-derived on every read.
    label = models.CharField(max_length=20)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_CLOSED)
    closed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    closed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-start_date"]
        indexes = [models.Index(fields=["business", "start_date", "end_date"])]

    def __str__(self):
        return f"{self.business.name} — {self.label} ({self.status})"


class StaffMember(models.Model):
    ROLE_OWNER = "OWNER"
    ROLE_MANAGER = "MANAGER"
    ROLE_CASHIER = "CASHIER"
    ROLE_VIEWER = "VIEWER"
    ROLE_CHOICES = [
        (ROLE_OWNER, "Owner"),
        (ROLE_MANAGER, "Manager"),
        (ROLE_CASHIER, "Cashier"),
        (ROLE_VIEWER, "Viewer"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="staff_roles")
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="staff")
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_CASHIER)
    permissions = models.JSONField(default=dict)
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)
    # Passwordless "click this link to open the app as this staff member"
    # credential (see accounts.views.StaffLoginView) — null until the owner
    # generates or regenerates one from Staff management. Nothing but the
    # token itself gates access, so treat it like a bearer password: never
    # returned to anyone but the business owner/a manager with staff-module
    # access, and regenerating instantly invalidates whatever link is out
    # there already.
    login_token = models.CharField(max_length=64, unique=True, null=True, blank=True, db_index=True)

    class Meta:
        unique_together = ("user", "business")
        ordering = ["joined_at"]

    def __str__(self):
        return f"{self.user.name} – {self.business.name} ({self.role})"

    @staticmethod
    def new_login_token():
        return secrets.token_urlsafe(32)

    def regenerate_login_token(self):
        self.login_token = self.new_login_token()
        self.save(update_fields=["login_token"])


class LoginActivity(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="login_activities")
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    success = models.BooleanField(default=True)
    logout_time = models.DateTimeField(null=True, blank=True)
    session_duration = models.DurationField(null=True, blank=True)

    class Meta:
        ordering = ["-timestamp"]
        verbose_name_plural = "login activities"


class StaffActivity(models.Model):
    ACTION_LOGIN = "LOGIN"
    ACTION_LOGOUT = "LOGOUT"
    ACTION_CREATE = "CREATE"
    ACTION_UPDATE = "UPDATE"
    ACTION_DELETE = "DELETE"
    ACTION_VIEW = "VIEW"
    ACTION_CHOICES = [
        (ACTION_LOGIN, "Login"),
        (ACTION_LOGOUT, "Logout"),
        (ACTION_CREATE, "Create"),
        (ACTION_UPDATE, "Update"),
        (ACTION_DELETE, "Delete"),
        (ACTION_VIEW, "View"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="activities")
    business = models.ForeignKey("Business", on_delete=models.CASCADE, related_name="staff_activities", null=True, blank=True)
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    module = models.CharField(max_length=50, blank=True)
    description = models.TextField(blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-timestamp"]
