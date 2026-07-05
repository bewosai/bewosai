from rest_framework import serializers
from .models import SupportTicket, Announcement


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
