from rest_framework import serializers
from .models import SupportTicket, Announcement, Feature, License, LicenseAuditLog


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
        read_only_fields = (
            "id", "code", "business_name", "email_snapshot", "duration_days",
            "expiry_date", "status", "activated_at", "revoked_at",
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
