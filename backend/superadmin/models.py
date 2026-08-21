import secrets

from django.conf import settings
from django.db import models, transaction, IntegrityError
from django.utils import timezone


class Feature(models.Model):
    """
    Master switch for an app module, set by the Super Admin and enforced on
    both the backend (permission check on the module's API views) and the
    frontends (Desktop/React and Mobile/Flutter both read the same effective
    map from EffectiveFeaturesView so they never drift apart). Disabling a
    feature here overrides any per-staff permission — see
    bewosai.permissions.require_feature docstring for the two-layer model.
    """

    key = models.SlugField(max_length=50, unique=True)
    name = models.CharField(max_length=100)
    description = models.CharField(max_length=300, blank=True)
    enabled = models.BooleanField(default=True)
    desktop_enabled = models.BooleanField(default=True)
    mobile_enabled = models.BooleanField(default=True)
    premium_only = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    def is_available_on(self, platform, business):
        """platform is 'mobile' or 'desktop' (anything else treated as desktop)."""
        if not self.enabled:
            return False
        if platform == "mobile" and not self.mobile_enabled:
            return False
        if platform != "mobile" and not self.desktop_enabled:
            return False
        if self.premium_only:
            from accounts.models import Business

            if not business or business.plan != Business.PLAN_PREMIUM:
                return False
        return True


class SupportTicket(models.Model):
    STATUS_OPEN = "OPEN"
    STATUS_IN_PROGRESS = "IN_PROGRESS"
    STATUS_CLOSED = "CLOSED"
    STATUS_CHOICES = [
        (STATUS_OPEN, "Open"),
        (STATUS_IN_PROGRESS, "In Progress"),
        (STATUS_CLOSED, "Closed"),
    ]

    user_email = models.EmailField()
    business_name = models.CharField(max_length=200, blank=True)
    subject = models.CharField(max_length=300)
    message = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_OPEN)
    admin_reply = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.subject} ({self.user_email})"


class Announcement(models.Model):
    title = models.CharField(max_length=300)
    body = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


# ── Licensing ────────────────────────────────────────────────────────────────
# A license belongs to a Business, not a bare User account — matching every
# other permission check in this codebase (IsPremiumBusiness, Feature.premium_only),
# since one user can own or staff multiple businesses. Every new business gets
# a 120-day trial computed from Business.created_at (see Business.trial_expiry_date)
# — no stored trial fields, nothing to drift out of sync.

LICENSE_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ2346789"  # no 0/1/I/O — avoids visual confusion
LICENSE_CODE_LENGTH = 5


def generate_license_code():
    """Cryptographically secure (secrets, not random/timestamp/email-derived),
    checked against the FULL license history including expired/revoked codes
    so nothing is ever reused. The DB's unique=True constraint is the final
    guard against a race between two concurrent generate calls."""
    for _ in range(50):
        code = "".join(secrets.choice(LICENSE_CODE_ALPHABET) for _ in range(LICENSE_CODE_LENGTH))
        if not License.objects.filter(code=code).exists():
            return code
    raise RuntimeError("Could not find an unused license code after 50 attempts — alphabet/length may be too small.")


class License(models.Model):
    DURATION_7D = "7D"
    DURATION_30D = "30D"
    DURATION_1Y = "1Y"
    DURATION_5Y = "5Y"
    DURATION_CUSTOM = "CUSTOM"
    DURATION_CHOICES = [
        (DURATION_7D, "7 Days"),
        (DURATION_30D, "30 Days"),
        (DURATION_1Y, "1 Year"),
        (DURATION_5Y, "5 Years"),
        (DURATION_CUSTOM, "Custom"),
    ]
    DURATION_DAYS = {DURATION_7D: 7, DURATION_30D: 30, DURATION_1Y: 365, DURATION_5Y: 365 * 5}

    STATUS_PENDING = "PENDING"  # generated, not yet activated by the business
    STATUS_ACTIVE = "ACTIVE"
    STATUS_EXPIRED = "EXPIRED"
    STATUS_REVOKED = "REVOKED"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_ACTIVE, "Active"),
        (STATUS_EXPIRED, "Expired"),
        (STATUS_REVOKED, "Revoked"),
    ]

    code = models.CharField(max_length=LICENSE_CODE_LENGTH, unique=True, editable=False)
    business = models.ForeignKey("accounts.Business", on_delete=models.CASCADE, related_name="licenses")
    email_snapshot = models.EmailField(help_text="Business owner's email at generation time — display/audit only.")
    plan = models.CharField(max_length=20, default="PREMIUM")
    duration_type = models.CharField(max_length=10, choices=DURATION_CHOICES)
    duration_days = models.PositiveIntegerField()
    start_date = models.DateField()
    expiry_date = models.DateField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_PENDING)
    activated_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="licenses_created",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.code} ({self.business.name})"

    @property
    def is_currently_active(self):
        return self.status == self.STATUS_ACTIVE and timezone.localdate() < self.expiry_date

    @classmethod
    def generate(cls, *, business, duration_type, start_date=None, duration_days=None, created_by=None):
        start_date = start_date or timezone.localdate()
        if duration_type == cls.DURATION_CUSTOM:
            if not duration_days:
                raise ValueError("duration_days is required when duration_type is 'CUSTOM'.")
        else:
            duration_days = cls.DURATION_DAYS[duration_type]
        expiry_date = start_date + timezone.timedelta(days=duration_days)

        for _ in range(10):
            code = generate_license_code()
            try:
                with transaction.atomic():
                    return cls.objects.create(
                        code=code,
                        business=business,
                        email_snapshot=business.email or business.owner.email,
                        duration_type=duration_type,
                        duration_days=duration_days,
                        start_date=start_date,
                        expiry_date=expiry_date,
                        created_by=created_by,
                    )
            except IntegrityError:
                continue  # another request grabbed this exact code first — retry with a fresh one
        raise RuntimeError("Could not create a license with a unique code after several attempts.")


class BusinessFeatureOverride(models.Model):
    """
    Per-business override of a Feature switch — a middle layer between the
    platform-wide Feature.enabled toggle and the business's plan, letting
    Super Admin grant or deny one specific feature to one specific business
    regardless of its plan, without touching the global switch everyone else
    depends on. See bewosai.permissions.require_feature for how the two
    combine.
    """

    business = models.ForeignKey("accounts.Business", on_delete=models.CASCADE, related_name="feature_overrides")
    feature_key = models.SlugField(max_length=50)
    enabled = models.BooleanField()
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("business", "feature_key")

    def __str__(self):
        return f"{self.business.name} · {self.feature_key} = {self.enabled}"


class LicenseAuditLog(models.Model):
    ACTION_CREATED = "CREATED"
    ACTION_ACTIVATED = "ACTIVATED"
    ACTION_EXTENDED = "EXTENDED"
    ACTION_REVOKED = "REVOKED"
    ACTION_REASSIGNED = "REASSIGNED"
    ACTION_FEATURE_ENABLED = "FEATURE_ENABLED"
    ACTION_FEATURE_DISABLED = "FEATURE_DISABLED"
    ACTION_CHOICES = [
        (ACTION_CREATED, "License Created"),
        (ACTION_ACTIVATED, "License Activated"),
        (ACTION_EXTENDED, "License Extended"),
        (ACTION_REVOKED, "License Revoked"),
        (ACTION_REASSIGNED, "License Reassigned"),
        (ACTION_FEATURE_ENABLED, "Feature Enabled"),
        (ACTION_FEATURE_DISABLED, "Feature Disabled"),
    ]

    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    business = models.ForeignKey("accounts.Business", on_delete=models.CASCADE, related_name="license_audit_logs")
    license = models.ForeignKey(License, on_delete=models.SET_NULL, null=True, blank=True, related_name="audit_logs")
    old_value = models.CharField(max_length=200, blank=True)
    new_value = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_action_display()} — {self.business.name}"
