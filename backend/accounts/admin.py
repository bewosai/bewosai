from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Business, StaffMember, LoginActivity, StaffActivity


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("email", "name", "phone", "account_type", "is_platform_admin", "is_active", "created_at")
    list_filter = ("is_platform_admin", "is_active", "is_staff", "account_type")
    search_fields = ("email", "name", "phone")
    ordering = ("-created_at",)
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal info", {"fields": ("name", "phone", "account_type")}),
        ("Permissions", {
            "fields": ("is_active", "is_staff", "is_superuser", "is_platform_admin", "is_verified"),
        }),
        ("Important dates", {"fields": ("last_login", "last_login_at", "created_at")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("email", "name", "phone", "password1", "password2"),
        }),
    )
    readonly_fields = ("created_at", "last_login_at")


@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "plan", "status", "staff_count", "created_at")
    list_filter = ("plan", "status")
    search_fields = ("name", "owner__email", "phone")
    readonly_fields = ("created_at", "updated_at")
    actions = ["suspend_businesses", "activate_businesses", "upgrade_to_premium"]

    def staff_count(self, obj):
        return obj.staff.filter(is_active=True).count()
    staff_count.short_description = "Staff"

    @admin.action(description="Suspend selected businesses")
    def suspend_businesses(self, request, queryset):
        queryset.update(status=Business.STATUS_SUSPENDED)

    @admin.action(description="Activate selected businesses")
    def activate_businesses(self, request, queryset):
        queryset.update(status=Business.STATUS_ACTIVE)

    @admin.action(description="Upgrade to Premium")
    def upgrade_to_premium(self, request, queryset):
        queryset.update(plan=Business.PLAN_PREMIUM)


@admin.register(StaffMember)
class StaffMemberAdmin(admin.ModelAdmin):
    list_display = ("user", "business", "role", "is_active", "joined_at")
    list_filter = ("role", "is_active")
    search_fields = ("user__email", "user__name", "business__name")
    readonly_fields = ("joined_at",)


@admin.register(LoginActivity)
class LoginActivityAdmin(admin.ModelAdmin):
    list_display = ("user", "ip_address", "success", "timestamp", "session_duration")
    list_filter = ("success",)
    search_fields = ("user__email",)
    readonly_fields = ("timestamp",)


@admin.register(StaffActivity)
class StaffActivityAdmin(admin.ModelAdmin):
    list_display = ("user", "business", "action", "module", "timestamp")
    list_filter = ("action",)
    search_fields = ("user__email", "module")
    readonly_fields = ("timestamp",)
