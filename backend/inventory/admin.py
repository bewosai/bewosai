from django.contrib import admin
from .models import Category, Unit, Product, StockMovement


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "business", "created_at")
    search_fields = ("name", "business__name")


@admin.register(Unit)
class UnitAdmin(admin.ModelAdmin):
    list_display = ("name", "abbreviation", "secondary_unit", "conversion_factor", "business")
    search_fields = ("name", "business__name")


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "business", "category", "stock_quantity", "sale_price", "is_active", "is_deleted")
    list_filter = ("is_active", "is_deleted", "category")
    search_fields = ("name", "barcode", "business__name")
    readonly_fields = ("created_at", "updated_at")
    list_editable = ("is_active",)


@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    list_display = ("product", "movement_type", "quantity", "created_by", "created_at")
    list_filter = ("movement_type",)
    search_fields = ("product__name",)
    readonly_fields = ("created_at",)
