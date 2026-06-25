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

    class Meta:
        model = Sale
        fields = (
            "id", "invoice_number", "customer", "customer_name",
            "sale_date", "due_date", "subtotal", "discount", "total",
            "paid_amount", "due_amount", "payment_method", "status",
            "notes", "items", "created_at",
        )
        read_only_fields = ("id", "due_amount", "created_at")

    def create(self, validated_data):
        items_data = validated_data.pop("items")
        sale = Sale.objects.create(**validated_data)
        for item_data in items_data:
            SaleItem.objects.create(sale=sale, **item_data)
        sale.subtotal = sum(i.total for i in sale.items.all())
        sale.total = sale.subtotal - sale.discount
        sale.save()
        return sale

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if items_data is not None:
            instance.items.all().delete()
            for item_data in items_data:
                SaleItem.objects.create(sale=instance, **item_data)
            instance.subtotal = sum(i.total for i in instance.items.all())
            instance.total = instance.subtotal - instance.discount
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
