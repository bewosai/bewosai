from django.contrib import admin
from .models import (
    SupportTicket, Announcement, Feature,
    License, BusinessFeatureOverride, LicenseAuditLog, ActivityLog,
)


@admin.register(Feature)
class FeatureAdmin(admin.ModelAdmin):
    list_display = ("name", "key", "enabled", "desktop_enabled", "mobile_enabled", "premium_only")
    list_filter = ("enabled", "premium_only")
    search_fields = ("name", "key")


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ("subject", "user_email", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("user_email", "subject")


@admin.register(Announcement)
class AnnouncementAdmin(admin.ModelAdmin):
    list_display = ("title", "is_active", "created_at")
    list_filter = ("is_active",)


@admin.register(License)
class LicenseAdmin(admin.ModelAdmin):
    list_display = ("code", "business", "plan", "duration_type", "status", "start_date", "expiry_date", "created_by")
    list_filter = ("plan", "duration_type", "status")
    search_fields = ("code", "business__name", "email_snapshot")
    readonly_fields = ("code", "created_at", "updated_at")


@admin.register(BusinessFeatureOverride)
class BusinessFeatureOverrideAdmin(admin.ModelAdmin):
    list_display = ("business", "feature_key", "enabled", "updated_by", "updated_at")
    list_filter = ("feature_key", "enabled")
    search_fields = ("business__name", "feature_key")
    readonly_fields = ("updated_at",)


@admin.register(LicenseAuditLog)
class LicenseAuditLogAdmin(admin.ModelAdmin):
    # Audit trail — every field is a record of something that already
    # happened, so nothing here should ever be hand-edited after the fact.
    list_display = ("action", "business", "license", "actor", "old_value", "new_value", "created_at")
    list_filter = ("action",)
    search_fields = ("business__name", "license__code")
    readonly_fields = [f.name for f in LicenseAuditLog._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    # Also populated automatically by signals (see superadmin/signals.py) —
    # read-only for the same reason as LicenseAuditLog above.
    list_display = ("action", "model_name", "object_repr", "business", "user", "created_at")
    list_filter = ("action", "model_name")
    search_fields = ("object_repr", "business__name", "user__email")
    readonly_fields = [f.name for f in ActivityLog._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
