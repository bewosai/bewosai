from decimal import Decimal
from django.db.models import Sum
from rest_framework import serializers
from inventory.models import Product
from .models import Sale, SaleItem, SaleReturn, SaleReturnItem, Quotation


class SaleItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = SaleItem
        fields = ("id", "product", "product_name", "quantity", "unit_price", "discount_amount", "total")
        read_only_fields = ("id", "total")


class SaleSerializer(serializers.ModelSerializer):
    items = SaleItemSerializer(many=True)
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    party_name    = serializers.CharField(source="customer.name", read_only=True)
    party_phone   = serializers.CharField(source="customer.phone", read_only=True)

    class Meta:
        model = Sale
        fields = (
            "id", "invoice_number", "customer", "customer_name", "party_name", "party_phone",
            "sale_date", "due_date", "subtotal", "discount", "tax_rate", "tax_amount", "total",
            "paid_amount", "due_amount", "payment_method", "status", "sale_type",
            "notes", "items", "created_at",
        )
        read_only_fields = ("id", "tax_amount", "total", "due_amount", "created_at",
                            "customer_name", "party_name", "party_phone")

    def create(self, validated_data):
        items_data = validated_data.pop("items")
        sale = Sale.objects.create(**validated_data)

        subtotal = Decimal("0")
        for item_data in items_data:
            item = SaleItem(sale=sale, **item_data)
            item.save()                     # computes item.total = qty*price - discount
            subtotal += item.total

            # Decrement stock for linked products
            if item.product_id:
                product = item.product
                product.stock_quantity = max(
                    Decimal("0"),
                    product.stock_quantity - item.quantity,
                )
                product.save(update_fields=["stock_quantity"])

        sale.subtotal = subtotal
        # model.save() recomputes tax_amount, total, due_amount
        sale.save()
        return sale

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Reverse old stock decrements before deleting items
        if items_data is not None:
            for old_item in instance.items.all():
                if old_item.product_id:
                    product = old_item.product
                    product.stock_quantity += old_item.quantity
                    product.save(update_fields=["stock_quantity"])
            instance.items.all().delete()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if items_data is not None:
            subtotal = Decimal("0")
            for item_data in items_data:
                item = SaleItem(sale=instance, **item_data)
                item.save()
                subtotal += item.total

                # Apply new stock decrements
                if item.product_id:
                    product = item.product
                    product.stock_quantity = max(
                        Decimal("0"),
                        product.stock_quantity - item.quantity,
                    )
                    product.save(update_fields=["stock_quantity"])

            instance.subtotal = subtotal
            # model.save() recomputes tax_amount, total, due_amount

        instance.save()
        return instance


class SaleReturnItemSerializer(serializers.ModelSerializer):
    sale_item = serializers.PrimaryKeyRelatedField(
        queryset=SaleItem.objects.all(), required=False, allow_null=True
    )
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = SaleReturnItem
        fields = ("id", "sale_item", "product", "product_name", "quantity", "unit_price", "total")
        read_only_fields = ("id", "total")


class SaleReturnSerializer(serializers.ModelSerializer):
    invoice_number = serializers.CharField(source="original_sale.invoice_number", read_only=True)
    items = SaleReturnItemSerializer(many=True, required=False)

    class Meta:
        model = SaleReturn
        fields = ("id", "original_sale", "invoice_number", "return_date", "reason", "amount", "items", "created_at")
        read_only_fields = ("id", "created_at", "invoice_number")

    def validate(self, data):
        for item in data.get("items", []):
            sale_item = item.get("sale_item")
            qty = item.get("quantity") or Decimal("0")
            if sale_item:
                already_returned = SaleReturnItem.objects.filter(sale_item=sale_item).aggregate(
                    total=Sum("quantity")
                )["total"] or Decimal("0")
                remaining = sale_item.quantity - already_returned
                if qty > remaining:
                    raise serializers.ValidationError(
                        f"Cannot return {qty} of '{sale_item.product_name}' — only "
                        f"{remaining} remaining from this invoice."
                    )
        return data

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        sale_return = SaleReturn.objects.create(**validated_data)

        for item_data in items_data:
            item = SaleReturnItem(sale_return=sale_return, **item_data)
            item.save()                     # computes item.total = qty*price

            # Restore stock for linked products
            if item.product_id:
                product = item.product
                product.stock_quantity += item.quantity
                product.save(update_fields=["stock_quantity"])

        return sale_return


class QuotationSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)

    class Meta:
        model = Quotation
        fields = (
            "id", "quotation_number", "customer", "customer_name",
            "date", "expiry_date", "subtotal", "discount", "total",
            "status", "notes", "created_at",
        )
        read_only_fields = ("id", "created_at", "customer_name", "quotation_number")
