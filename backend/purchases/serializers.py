from decimal import Decimal
from rest_framework import serializers
from inventory.models import Product
from .models import Purchase, PurchaseItem, PurchaseReturn


class PurchaseItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = PurchaseItem
        fields = ["id", "product", "product_name", "quantity", "unit_price", "discount_amount", "total"]
        read_only_fields = ["id", "total"]


class PurchaseSerializer(serializers.ModelSerializer):
    items = PurchaseItemSerializer(many=True, required=False)
    bill_number    = serializers.CharField(required=False, allow_blank=True)
    supplier_name  = serializers.CharField(source="supplier.name", read_only=True)
    bill_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Purchase
        fields = ["id", "bill_number", "supplier", "supplier_name", "purchase_date", "due_date",
                  "subtotal", "discount", "total", "paid_amount", "due_amount",
                  "payment_method", "status", "notes", "bill_image", "bill_image_url",
                  "is_deleted", "items", "created_at"]
        read_only_fields = ["due_amount", "created_at", "bill_image_url"]

    def get_bill_image_url(self, obj):
        if not obj.bill_image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.bill_image.url)
        return obj.bill_image.url

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        purchase = Purchase.objects.create(**validated_data)
        subtotal = Decimal("0")
        for item_data in items_data:
            item = PurchaseItem(purchase=purchase, **item_data)
            item.save()                     # computes item.total
            subtotal += item.total
            if item.product_id:
                product = item.product
                product.stock_quantity = (product.stock_quantity or Decimal("0")) + item.quantity
                product.save(update_fields=["stock_quantity"])
        purchase.subtotal = subtotal
        purchase.total    = subtotal - purchase.discount
        purchase.save()                     # computes due_amount
        return purchase

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Reverse old stock increments before replacing items
        if items_data is not None:
            for old_item in instance.items.all():
                if old_item.product_id:
                    product = old_item.product
                    product.stock_quantity = max(
                        Decimal("0"),
                        product.stock_quantity - old_item.quantity,
                    )
                    product.save(update_fields=["stock_quantity"])
            instance.items.all().delete()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if items_data is not None:
            subtotal = Decimal("0")
            for item_data in items_data:
                item = PurchaseItem(purchase=instance, **item_data)
                item.save()
                subtotal += item.total
                if item.product_id:
                    product = item.product
                    product.stock_quantity = (product.stock_quantity or Decimal("0")) + item.quantity
                    product.save(update_fields=["stock_quantity"])
            instance.subtotal = subtotal
            instance.total    = subtotal - instance.discount

        instance.save()
        return instance


class PurchaseReturnSerializer(serializers.ModelSerializer):
    original_purchase_number = serializers.CharField(
        source="original_purchase.bill_number", read_only=True
    )

    class Meta:
        model = PurchaseReturn
        fields = ["id", "original_purchase", "original_purchase_number",
                  "return_date", "reason", "amount", "created_at"]
        read_only_fields = ["id", "created_at", "original_purchase_number"]
