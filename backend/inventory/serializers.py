from rest_framework import serializers
from bewosai.validators import IMAGE_VALIDATORS
from .models import Category, Unit, Product, StockMovement


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "description", "created_at")
        read_only_fields = ("id", "created_at")


class UnitSerializer(serializers.ModelSerializer):
    display = serializers.CharField(read_only=True)

    class Meta:
        model = Unit
        fields = (
            "id", "name", "abbreviation",
            "secondary_unit", "secondary_abbreviation", "conversion_factor",
            "display",
        )
        read_only_fields = ("id", "display")


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    unit_name = serializers.CharField(source="unit.name", read_only=True)
    # Full primary/secondary/conversion_factor detail so billing screens can
    # offer a unit picker per line item without a separate Units lookup.
    unit_detail = UnitSerializer(source="unit", read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)
    # Alias used by the Flutter app (selling_price → sale_price)
    selling_price = serializers.DecimalField(
        source="sale_price", max_digits=12, decimal_places=2, read_only=True
    )

    class Meta:
        model = Product
        fields = (
            "id", "name", "category", "category_name", "unit", "unit_name", "unit_detail",
            "description", "purchase_price", "sale_price", "selling_price",
            "stock_quantity", "low_stock_threshold", "is_low_stock",
            "barcode", "hs_code", "image", "is_active", "created_at",
        )
        read_only_fields = ("id", "created_at", "is_low_stock", "selling_price")
        extra_kwargs = {"image": {"validators": IMAGE_VALIDATORS}}


class StockMovementSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    created_by_name = serializers.CharField(source="created_by.name", read_only=True)

    class Meta:
        model = StockMovement
        fields = (
            "id", "product", "product_name",
            "movement_type", "quantity", "note",
            "created_by_name", "created_at",
        )
        read_only_fields = ("id", "created_at", "created_by_name", "product_name")
