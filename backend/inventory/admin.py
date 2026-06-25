from django.contrib import admin
from .models import Category, Unit, Product, StockMovement

admin.site.register(Category)
admin.site.register(Unit)


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "business", "stock_quantity", "sale_price", "is_active")
    list_filter = ("is_active", "category")
    search_fields = ("name", "barcode")


@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    list_display = ("product", "movement_type", "quantity", "created_at")
    list_filter = ("movement_type",)
