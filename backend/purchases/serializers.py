from rest_framework import serializers
from .models import Purchase, PurchaseItem, PurchaseReturn


class PurchaseItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PurchaseItem
        fields = ["id", "product", "product_name", "quantity", "unit_price", "discount_amount", "total"]


class PurchaseSerializer(serializers.ModelSerializer):
    items = PurchaseItemSerializer(many=True, required=False)
    supplier_name = serializers.CharField(source="supplier.name", read_only=True)

    class Meta:
        model = Purchase
        fields = ["id", "bill_number", "supplier", "supplier_name", "purchase_date", "due_date",
                  "subtotal", "discount", "total", "paid_amount", "due_amount",
                  "payment_method", "status", "notes", "is_deleted", "items", "created_at"]
        read_only_fields = ["due_amount", "created_at"]

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        purchase = Purchase.objects.create(**validated_data)
        subtotal = 0
        for item_data in items_data:
            item = PurchaseItem(purchase=purchase, **item_data)
            item.save()
            subtotal += item.total
            # Update stock
            if item.product:
                item.product.stock_quantity = (item.product.stock_quantity or 0) + float(item.quantity)
                item.product.save(update_fields=["stock_quantity"])
        purchase.subtotal = subtotal
        purchase.total = subtotal - purchase.discount
        purchase.save()
        return purchase


class PurchaseReturnSerializer(serializers.ModelSerializer):
    class Meta:
        model = PurchaseReturn
        fields = "__all__"
