from rest_framework import serializers
from .models import SupportTicket, Announcement, Feature


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
