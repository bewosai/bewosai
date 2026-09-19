from django.contrib import admin

from .models import Coupon, Referral, Subscription


@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ("code", "user", "plan", "computed_status", "source", "used_for_business", "start_date", "end_date")
    list_filter = ("plan", "source", "is_active", "is_used")
    search_fields = ("code", "user__email", "user__name", "used_for_business__name")
    readonly_fields = ("code", "created_at", "used_at")


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("business", "user", "plan", "status", "source", "start_date", "end_date")
    list_filter = ("plan", "status", "source")
    search_fields = ("business__name", "user__email")
    readonly_fields = ("created_at",)


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ("referrer_business", "referred_business", "status", "registered_at", "rewarded_at")
    list_filter = ("status",)
    search_fields = ("referrer_business__name", "referred_business__name")
    readonly_fields = ("registered_at", "verified_at", "rewarded_at")
