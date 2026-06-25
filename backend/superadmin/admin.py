from django.contrib import admin
from .models import SupportTicket, Announcement


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ("subject", "user_email", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("user_email", "subject")


@admin.register(Announcement)
class AnnouncementAdmin(admin.ModelAdmin):
    list_display = ("title", "is_active", "created_at")
    list_filter = ("is_active",)
