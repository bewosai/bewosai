from django.contrib import admin
from .models import Party, PartyPayment, PaymentAllocation


class PaymentAllocationInline(admin.TabularInline):
    model = PaymentAllocation
    extra = 0


@admin.register(Party)
class PartyAdmin(admin.ModelAdmin):
    list_display = ("name", "business", "party_type", "opening_balance", "is_active", "is_deleted")
    list_filter = ("party_type", "is_active", "is_deleted")
    search_fields = ("name", "phone", "business__name")


@admin.register(PartyPayment)
class PartyPaymentAdmin(admin.ModelAdmin):
    list_display = ("party", "payment_type", "amount", "payment_method", "date", "is_deleted")
    list_filter = ("payment_type", "payment_method", "is_deleted")
    search_fields = ("party__name",)
    inlines = [PaymentAllocationInline]
