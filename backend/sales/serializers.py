from decimal import Decimal
from rest_framework import serializers
from .models import Sale, SaleItem, SaleReturn, Quotation


class SaleItemSerializer(serializers.ModelSerializer):
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


class SaleReturnSerializer(serializers.ModelSerializer):
    invoice_number = serializers.CharField(source="original_sale.invoice_number", read_only=True)

    class Meta:
        model = SaleReturn
        fields = ("id", "original_sale", "invoice_number", "return_date", "reason", "amount", "created_at")
        read_only_fields = ("id", "created_at", "invoice_number")


class QuotationSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)

    class Meta:
        model = Quotation
        fields = (
            "id", "quotation_number", "customer", "customer_name",
            "date", "expiry_date", "subtotal", "discount", "total",
            "status", "notes", "created_at",
        )
        read_only_fields = ("id", "created_at", "customer_name")
