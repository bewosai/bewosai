from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Business, StaffMember, LoginActivity


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("email", "name", "phone", "is_platform_admin", "is_active", "created_at")
    list_filter = ("is_platform_admin", "is_active", "is_staff")
    search_fields = ("email", "name", "phone")
    ordering = ("-created_at",)
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal", {"fields": ("name", "phone")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "is_platform_admin")}),
    )
    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": ("email", "name", "phone", "password1", "password2")}),
    )


@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "plan", "status", "created_at")
    list_filter = ("plan", "status")
    search_fields = ("name", "owner__email")


@admin.register(StaffMember)
class StaffMemberAdmin(admin.ModelAdmin):
    list_display = ("user", "business", "role", "is_active", "joined_at")
    list_filter = ("role", "is_active")


@admin.register(LoginActivity)
class LoginActivityAdmin(admin.ModelAdmin):
    list_display = ("user", "ip_address", "success", "timestamp")
    list_filter = ("success",)
