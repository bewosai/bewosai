from django.contrib import admin
from .models import Purchase, PurchaseItem, PurchaseReturn, PurchaseReturnItem


class PurchaseItemInline(admin.TabularInline):
    model = PurchaseItem
    extra = 0


class PurchaseReturnItemInline(admin.TabularInline):
    model = PurchaseReturnItem
    extra = 0


@admin.register(Purchase)
class PurchaseAdmin(admin.ModelAdmin):
    list_display = ("bill_number", "business", "supplier", "total", "status", "purchase_date")
    list_filter = ("status", "payment_method")
    search_fields = ("bill_number", "supplier__name")
    inlines = [PurchaseItemInline]


@admin.register(PurchaseReturn)
class PurchaseReturnAdmin(admin.ModelAdmin):
    list_display = ("original_purchase", "amount", "return_date")
    search_fields = ("original_purchase__bill_number",)
    inlines = [PurchaseReturnItemInline]
