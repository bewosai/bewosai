from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from accounts.serializers import UserSerializer
from .models import SupportTicket, Announcement, Feature, License, LicenseAuditLog, ActivityLog


class FeatureSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feature
        fields = (
            "id", "key", "name", "description", "enabled",
            "desktop_enabled", "mobile_enabled", "premium_only",
            "updated_at",
        )
        read_only_fields = ("id", "key", "updated_at")


class SupportTicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = (
            "id", "user_email", "business_name",
            "subject", "message", "status", "admin_reply",
            "created_at", "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class AnnouncementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Announcement
        fields = ("id", "title", "body", "is_active", "created_at")
        read_only_fields = ("id", "created_at")


class LicenseSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source="business.name", read_only=True)
    created_by_name = serializers.CharField(source="created_by.name", read_only=True, default="")

    class Meta:
        model = License
        fields = (
            "id", "code", "business", "business_name", "email_snapshot", "plan",
            "duration_type", "duration_days", "start_date", "expiry_date", "status",
            "activated_at", "revoked_at", "created_by", "created_by_name",
            "created_at", "updated_at",
        )
        # code is immutable once generated (spec: "Do not allow editing the
        # actual license code"); status/activated_at/revoked_at only change
        # through the dedicated activate/extend/revoke actions, not raw PATCH.
        # business/duration_type/start_date are also locked here — moving a
        # license to another business must go through LicenseReassignView
        # (which blocks reassigning an active license), and changing the
        # duration/start date without recomputing expiry_date would desync
        # the two — extend/revoke are the only paths that touch either.
        read_only_fields = (
            "id", "code", "business", "business_name", "email_snapshot",
            "duration_type", "duration_days", "start_date", "expiry_date",
            "status", "activated_at", "revoked_at",
            "created_by", "created_by_name", "created_at", "updated_at",
        )


class LicenseAuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.name", read_only=True, default="")
    business_name = serializers.CharField(source="business.name", read_only=True)
    license_code = serializers.CharField(source="license.code", read_only=True, default="")

    class Meta:
        model = LicenseAuditLog
        fields = (
            "id", "actor", "actor_name", "action", "business", "business_name",
            "license", "license_code", "old_value", "new_value", "created_at",
        )
        read_only_fields = fields


class ActivityLogSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True, default="")
    business_name = serializers.CharField(source="business.name", read_only=True)

    class Meta:
        model = ActivityLog
        fields = (
            "id", "business", "business_name", "user", "user_name",
            "action", "model_name", "object_repr", "created_at",
        )
        read_only_fields = fields


class AdminUserSerializer(UserSerializer):
    """A user as Super Admin's Users list sees them: the usual profile fields plus
    how they use the app — last sign-in, last activity, sign-in count, and the
    device/IP of the latest sign-in. The three annotated values (login_count,
    last_login_ip, last_login_ua) are added by UserManagementView's queryset."""

    # Recent enough to call someone "online": last_active_at is only written every
    # ~5 minutes (accounts.authentication), so allow that lag plus a margin.
    ONLINE_WINDOW = timedelta(minutes=10)

    login_count = serializers.IntegerField(read_only=True, default=0)
    last_login_ip = serializers.CharField(read_only=True, default=None, allow_null=True)
    last_login_device = serializers.SerializerMethodField()
    is_online = serializers.SerializerMethodField()

    class Meta(UserSerializer.Meta):
        fields = UserSerializer.Meta.fields + (
            "last_login_at", "last_active_at", "login_count", "last_login_ip", "last_login_device", "is_online",
        )
        read_only_fields = fields

    def get_last_login_device(self, obj):
        ua = getattr(obj, "last_login_ua", None)
        if not ua:
            return None
        from .views import _device_label  # local import: views imports this module

        return _device_label(ua)

    def get_is_online(self, obj):
        return bool(obj.last_active_at and timezone.now() - obj.last_active_at <= self.ONLINE_WINDOW)
