from django.db import models


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
