from rest_framework import serializers
from .models import User, Business, StaffMember


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "email", "name", "phone", "account_type", "is_platform_admin", "is_verified", "created_at")
        read_only_fields = ("id", "is_platform_admin", "is_verified", "created_at")


class BusinessSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source="owner.name", read_only=True)
    staff_count = serializers.SerializerMethodField()

    class Meta:
        model = Business
        fields = (
            "id", "name", "business_type", "address", "phone", "email",
            "logo", "plan", "status", "subscription_expires",
            "owner", "owner_name", "staff_count", "created_at",
        )
        read_only_fields = ("id", "owner", "created_at")

    def get_staff_count(self, obj):
        return obj.staff.filter(is_active=True).count()


class StaffMemberSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    user_email = serializers.CharField(source="user.email", read_only=True)

    class Meta:
        model = StaffMember
        fields = ("id", "user", "user_name", "user_email", "business", "role", "permissions", "is_active", "joined_at")
        read_only_fields = ("id", "joined_at")


class InviteStaffSerializer(serializers.Serializer):
    email = serializers.EmailField()
    name = serializers.CharField(max_length=150)
    role = serializers.ChoiceField(choices=StaffMember.ROLE_CHOICES)
