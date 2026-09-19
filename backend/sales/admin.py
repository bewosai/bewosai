from django.contrib import admin
from .models import Sale, SaleItem, SaleReturn, SaleReturnItem, Quotation


class SaleItemInline(admin.TabularInline):
    model = SaleItem
    extra = 0


class SaleReturnItemInline(admin.TabularInline):
    model = SaleReturnItem
    extra = 0


@admin.register(Sale)
class SaleAdmin(admin.ModelAdmin):
    list_display = ("invoice_number", "business", "customer", "total", "status", "sale_date")
    list_filter = ("status", "payment_method")
    search_fields = ("invoice_number", "customer__name")
    inlines = [SaleItemInline]


@admin.register(SaleReturn)
class SaleReturnAdmin(admin.ModelAdmin):
    list_display = ("original_sale", "amount", "return_date")
    search_fields = ("original_sale__invoice_number",)
    inlines = [SaleReturnItemInline]


@admin.register(Quotation)
class QuotationAdmin(admin.ModelAdmin):
    list_display = ("quotation_number", "business", "customer", "total", "status", "date")
    list_filter = ("status",)
    search_fields = ("quotation_number", "customer__name")
