import secrets

from django.conf import settings
from django.db import models
from django.utils import timezone

from accounts.models import Business

# ── Coupons & subscriptions ─────────────────────────────────────────────────
# Deliberately separate from superadmin.models.License (which already covers
# "superadmin issues a code, business activates it") — kept apart per an
# explicit product decision, not because the two don't overlap. The two
# systems never fight over the same field: License still only ever sets
# Business.plan directly (unchanged); this app layers a Subscription on top,
# and Business.effective_plan (accounts/models.py) takes the higher of the
# two. See PLAN_CHOICES on Business for the tier values reused here.

COUPON_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ2346789"  # no 0/1/I/O — avoids visual confusion, same alphabet superadmin.License uses
COUPON_CODE_LENGTH = 6


def generate_coupon_code():
    for _ in range(50):
        code = "".join(secrets.choice(COUPON_CODE_ALPHABET) for _ in range(COUPON_CODE_LENGTH))
        if not Coupon.objects.filter(code=code).exists():
            return code
    raise RuntimeError("Could not find an unused coupon code after 50 attempts.")


class Coupon(models.Model):
    SOURCE_ADMIN = "ADMIN"
    SOURCE_REFERRAL = "REFERRAL"
    SOURCE_CHOICES = [(SOURCE_ADMIN, "Admin"), (SOURCE_REFERRAL, "Referral")]

    PLAN_CHOICES = [
        (Business.PLAN_PREMIUM, "Premium"),
        (Business.PLAN_PREMIUMPLUS, "Premium Plus"),
    ]

    code = models.CharField(max_length=COUPON_CODE_LENGTH, unique=True, editable=False, db_index=True)
    # Tied to a *user*, not a business — a coupon is "for this verified
    # person"; which business it ends up applied to is recorded separately
    # in used_for_business once they redeem it (a user can own more than
    # one business, and picks which one gets the entitlement at apply time).
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name="coupons", on_delete=models.CASCADE)
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES)
    start_date = models.DateField()
    end_date = models.DateField()
    is_active = models.BooleanField(default=True)  # admin disable/cancel
    is_used = models.BooleanField(default=False)
    used_at = models.DateTimeField(null=True, blank=True)
    used_for_business = models.ForeignKey(Business, null=True, blank=True, on_delete=models.SET_NULL, related_name="coupons_redeemed")
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default=SOURCE_ADMIN)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="coupons_created",
    )  # null for system-granted referral rewards — nobody "created" those by hand
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.code} ({self.get_plan_display()})"

    @property
    def computed_status(self):
        """ACTIVE / USED / EXPIRED / CANCELLED — never trust is_active alone;
        dates and is_used always win, so an expired or redeemed coupon stops
        working even if nobody remembered to flip is_active."""
        today = timezone.localdate()
        if not self.is_active:
            return "CANCELLED"
        if self.is_used:
            return "USED"
        if today > self.end_date:
            return "EXPIRED"
        return "ACTIVE"

    @classmethod
    def generate(cls, *, user, plan, start_date, end_date, source=SOURCE_ADMIN, created_by=None):
        for _ in range(10):
            code = generate_coupon_code()
            try:
                return cls.objects.create(
                    code=code, user=user, plan=plan, start_date=start_date, end_date=end_date,
                    source=source, created_by=created_by,
                )
            except Exception:
                continue
        raise RuntimeError("Could not create a coupon with a unique code after several attempts.")


class Subscription(models.Model):
    """The actual entitlement a coupon grants once redeemed — kept separate
    from Coupon so renewals/history/reporting stay clean (a business can
    accumulate many Subscription rows over time; each Coupon is redeemed
    exactly once)."""

    STATUS_ACTIVE = "ACTIVE"
    STATUS_EXPIRED = "EXPIRED"
    STATUS_CANCELLED = "CANCELLED"
    STATUS_CHOICES = [(STATUS_ACTIVE, "Active"), (STATUS_EXPIRED, "Expired"), (STATUS_CANCELLED, "Cancelled")]

    # Aliases onto Coupon's source constants — `source` here is always
    # denormalized straight from the coupon that granted it, so this avoids
    # having to remember which model actually owns SOURCE_ADMIN/REFERRAL.
    SOURCE_ADMIN = Coupon.SOURCE_ADMIN
    SOURCE_REFERRAL = Coupon.SOURCE_REFERRAL

    business = models.ForeignKey(Business, related_name="subscriptions", on_delete=models.CASCADE)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name="subscriptions", on_delete=models.CASCADE)
    plan = models.CharField(max_length=20, choices=Coupon.PLAN_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    start_date = models.DateField()
    end_date = models.DateField()
    source = models.CharField(max_length=20, choices=Coupon.SOURCE_CHOICES)  # denormalized from coupon.source for easy filtering/reporting
    coupon = models.ForeignKey(Coupon, related_name="subscriptions", on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.business.name} — {self.get_plan_display()} until {self.end_date}"

    @property
    def is_currently_active(self):
        return self.status == self.STATUS_ACTIVE and timezone.localdate() <= self.end_date


# ── Referrals ────────────────────────────────────────────────────────────────

class Referral(models.Model):
    """
    One row per successful "business B signed up using business A's referral
    code" event. Only ever created once a real Business exists (this app's
    signup flow already requires OTP verification before a Business can be
    created at all, so REGISTERED and VERIFIED happen at effectively the
    same moment here — there's no separate later "confirm your email" step
    to track). STATUS_CLICKED is reserved for a possible future
    pre-signup click-tracking pass; nothing writes it yet, since there's no
    account to attach an anonymous click to.
    """

    STATUS_CLICKED = "CLICKED"
    STATUS_REGISTERED = "REGISTERED"
    STATUS_VERIFIED = "VERIFIED"
    STATUS_REWARDED = "REWARDED"
    STATUS_REJECTED = "REJECTED"
    STATUS_EXPIRED = "EXPIRED"
    STATUS_CHOICES = [
        (STATUS_CLICKED, "Clicked"),
        (STATUS_REGISTERED, "Registered"),
        (STATUS_VERIFIED, "Verified"),
        (STATUS_REWARDED, "Rewarded"),
        (STATUS_REJECTED, "Rejected"),
        (STATUS_EXPIRED, "Expired"),
    ]

    referrer_business = models.ForeignKey(Business, related_name="referrals_made", on_delete=models.CASCADE)
    # OneToOne: a business can only ever be the *referred* side of one
    # referral, ever (matches Business.referred_by being set once, never
    # reassignable) — this is the audit-trail twin of that field.
    referred_business = models.OneToOneField(Business, related_name="referred_via", on_delete=models.CASCADE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_REGISTERED)
    reject_reason = models.CharField(max_length=200, blank=True)
    registered_at = models.DateTimeField(auto_now_add=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    rewarded_at = models.DateTimeField(null=True, blank=True)
    referrer_subscription = models.ForeignKey(Subscription, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    referred_subscription = models.ForeignKey(Subscription, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")

    class Meta:
        ordering = ["-registered_at"]

    def __str__(self):
        return f"{self.referrer_business.name} → {self.referred_business.name} ({self.status})"
