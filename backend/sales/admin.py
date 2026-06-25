from django.contrib import admin
from .models import Sale, SaleItem, SaleReturn, Quotation


class SaleItemInline(admin.TabularInline):
    model = SaleItem
    extra = 0


@admin.register(Sale)
class SaleAdmin(admin.ModelAdmin):
    list_display = ("invoice_number", "business", "customer", "total", "status", "sale_date")
    list_filter = ("status", "payment_method")
    search_fields = ("invoice_number", "customer__name")
    inlines = [SaleItemInline]


admin.site.register(SaleReturn)
admin.site.register(Quotation)
