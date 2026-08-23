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
    def create_user(self, email, name="", password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, name=name, **extra_fields)
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
        return self.create_user(email, name, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
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

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    def __str__(self):
        return self.email


class OTPCode(models.Model):
    MAX_ATTEMPTS = 5
    RESEND_COOLDOWN_SECONDS = 60

    email = models.EmailField()
    code_hash = models.CharField(max_length=128)
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPE_CHOICES, default=ACCOUNT_BUSINESS)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.email} – OTP ({'used' if self.is_used else 'active'})"

    @property
    def is_valid(self):
        return not self.is_used and self.expires_at > timezone.now()

    @classmethod
    def generate(cls, email, account_type):
        """Create a new OTP, invalidating any prior unused ones. Returns (otp, plaintext_code)."""
        cls.objects.filter(email=email, is_used=False).update(is_used=True)
        code = str(secrets.SystemRandom().randint(100000, 999999))
        otp = cls.objects.create(
            email=email,
            code_hash=make_password(code),
            account_type=account_type,
            expires_at=timezone.now() + timedelta(minutes=10),
        )
        return otp, code

    @classmethod
    def seconds_until_resend(cls, email):
        """Seconds the caller must still wait before requesting another OTP, or 0 if allowed now."""
        last = cls.objects.filter(email=email).order_by("-created_at").first()
        if not last:
            return 0
        elapsed = (timezone.now() - last.created_at).total_seconds()
        remaining = cls.RESEND_COOLDOWN_SECONDS - elapsed
        return max(0, int(remaining))

    @classmethod
    def verify_and_consume(cls, email, code):
        """
        Validate `code` for `email` and mark it used on success.
        Returns (otp_or_None, error_code) where error_code is one of
        None, "invalid", "expired", "too_many_attempts".
        """
        with transaction.atomic():
            otp = (
                cls.objects.select_for_update()
                .filter(email=email, is_used=False, expires_at__gt=timezone.now())
                .order_by("-created_at")
                .first()
            )
            if not otp:
                # An unused-but-expired row means the user had a valid code
                # that simply timed out (10 min) rather than typed the wrong
                # digits — worth telling apart since the fix differs (request
                # a new code vs. re-check what you typed). A "Resend" marks
                # the old row is_used=True, so it won't match here either.
                had_unused = cls.objects.filter(email=email, is_used=False).exists()
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
    PLAN_CHOICES = [(PLAN_FREE, "Free"), (PLAN_PREMIUM, "Premium")]

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
    def has_active_subscription(self):
        """The single source of truth for 'can this business use the app right
        now' — grandfathered, or trial window, or a currently-active license.
        Server time only; never trust a client-supplied date."""
        return self.is_grandfathered or self.is_trial_active or self.active_license is not None


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

    class Meta:
        unique_together = ("user", "business")
        ordering = ["joined_at"]

    def __str__(self):
        return f"{self.user.name} – {self.business.name} ({self.role})"


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
