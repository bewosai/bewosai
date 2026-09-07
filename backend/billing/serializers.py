from rest_framework import serializers

from .models import Coupon, Referral, Subscription


class CouponSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    user_email = serializers.CharField(source="user.email", read_only=True)
    user_phone = serializers.CharField(source="user.phone", read_only=True)
    used_for_business_name = serializers.CharField(source="used_for_business.name", read_only=True)
    created_by_name = serializers.CharField(source="created_by.name", read_only=True)
    status = serializers.CharField(source="computed_status", read_only=True)

    class Meta:
        model = Coupon
        fields = (
            "id", "code", "user", "user_name", "user_email", "user_phone",
            "plan", "start_date", "end_date", "is_active", "is_used", "used_at",
            "used_for_business", "used_for_business_name", "source",
            "created_by", "created_by_name", "created_at", "status",
        )
        # code/is_used/used_at/used_for_business/source are all lifecycle
        # state, not something a PATCH should touch directly — the same
        # "immutable code, lifecycle only through dedicated actions" rule
        # superadmin.LicenseSerializer already follows.
        read_only_fields = (
            "id", "code", "is_used", "used_at", "used_for_business",
            "source", "created_by", "created_at",
        )


class SubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subscription
        fields = ("id", "business", "user", "plan", "status", "start_date", "end_date", "source", "coupon", "created_at")
        read_only_fields = fields


class ReferralSerializer(serializers.ModelSerializer):
    referrer_business_name = serializers.CharField(source="referrer_business.name", read_only=True)
    referrer_owner_email = serializers.CharField(source="referrer_business.owner.email", read_only=True)
    referred_business_name = serializers.CharField(source="referred_business.name", read_only=True)
    referred_owner_email = serializers.CharField(source="referred_business.owner.email", read_only=True)

    class Meta:
        model = Referral
        fields = (
            "id", "referrer_business", "referrer_business_name", "referrer_owner_email",
            "referred_business", "referred_business_name", "referred_owner_email",
            "status", "reject_reason", "registered_at", "verified_at", "rewarded_at",
        )
        read_only_fields = fields
