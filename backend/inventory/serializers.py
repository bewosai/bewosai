from rest_framework import serializers
from .models import Category, Unit, Product, StockMovement


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "description", "created_at")
        read_only_fields = ("id", "created_at")


class UnitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Unit
        fields = ("id", "name", "abbreviation")
        read_only_fields = ("id",)


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    unit_name = serializers.CharField(source="unit.name", read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)

    class Meta:
        model = Product
        fields = (
            "id", "name", "category", "category_name", "unit", "unit_name",
            "description", "purchase_price", "sale_price",
            "stock_quantity", "low_stock_threshold", "is_low_stock",
            "barcode", "image", "is_active", "created_at",
        )
        read_only_fields = ("id", "created_at", "is_low_stock")


class StockMovementSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    created_by_name = serializers.CharField(source="created_by.name", read_only=True)

    class Meta:
        model = StockMovement
        fields = ("id", "product", "product_name", "movement_type", "quantity", "note", "created_by_name", "created_at")
        read_only_fields = ("id", "created_at", "created_by_name")
