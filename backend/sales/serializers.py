from decimal import Decimal
from django.db.models import Sum, F
from django.db.models.functions import Greatest
from rest_framework import serializers
from bewosai.utils import require_business, sync_bank_transaction
from inventory.models import Product
from .models import Sale, SaleItem, SaleReturn, SaleReturnItem, Quotation


class SaleItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = SaleItem
        fields = ("id", "product", "product_name", "quantity", "unit_price", "unit_cost", "discount_amount", "total")
        read_only_fields = ("id", "unit_cost", "total")


class SaleSerializer(serializers.ModelSerializer):
    items = SaleItemSerializer(many=True)
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    party_name    = serializers.CharField(source="customer.name", read_only=True)
    party_phone   = serializers.CharField(source="customer.phone", read_only=True)
    party_pan     = serializers.CharField(source="customer.pan_number", read_only=True, default="")
    party_address = serializers.CharField(source="customer.address", read_only=True, default="")

    class Meta:
        model = Sale
        fields = (
            "id", "invoice_number", "customer", "customer_name", "party_name", "party_phone",
            "party_pan", "party_address",
            "sale_date", "due_date", "subtotal", "discount", "tax_rate", "tax_amount", "total",
            "paid_amount", "due_amount", "payment_method", "bank_account", "status", "sale_type",
            "reminder_enabled", "reminder_at",
            "notes", "items", "created_at",
        )
        read_only_fields = ("id", "tax_amount", "total", "due_amount", "created_at",
                            "customer_name", "party_name", "party_phone", "party_pan", "party_address")

    def validate(self, data):
        business = require_business(self.context["request"])
        customer = data.get("customer")
        if customer is not None and customer.business_id != business.id:
            raise serializers.ValidationError({"customer": "Invalid customer for this business."})
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        for item in data.get("items", []):
            product = item.get("product")
            if product is not None and product.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid product for this business."})
        return data

    @staticmethod
    def _sync_bank(sale):
        sync_bank_transaction(
            reference=f"SALE-{sale.id}",
            bank_account=sale.bank_account if sale.payment_method != "CASH" else None,
            transaction_type="CREDIT",
            amount=sale.paid_amount,
            date=sale.sale_date,
            description=f"Sale {sale.invoice_number}" + (f" — {sale.customer.name}" if sale.customer_id else ""),
            created_by=sale.created_by,
        )

    def create(self, validated_data):
        items_data = validated_data.pop("items")
        sale = Sale.objects.create(**validated_data)

        subtotal = Decimal("0")
        for item_data in items_data:
            item = SaleItem(sale=sale, **item_data)
            item.save()                     # computes item.total = qty*price - discount
            subtotal += item.total

            # Decrement stock for linked products via an atomic F()-expression
            # UPDATE (not read-modify-write) so two concurrent sales of the
            # same product can't race and silently lose one decrement.
            if item.product_id:
                Product.objects.filter(pk=item.product_id).update(
                    stock_quantity=Greatest(F("stock_quantity") - item.quantity, Decimal("0"))
                )

        sale.subtotal = subtotal
        # model.save() recomputes tax_amount, total, due_amount
        sale.save()
        self._sync_bank(sale)
        return sale

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Reverse old stock decrements before deleting items
        if items_data is not None:
            for old_item in instance.items.all():
                if old_item.product_id:
                    Product.objects.filter(pk=old_item.product_id).update(
                        stock_quantity=F("stock_quantity") + old_item.quantity
                    )
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
                    Product.objects.filter(pk=item.product_id).update(
                        stock_quantity=Greatest(F("stock_quantity") - item.quantity, Decimal("0"))
                    )

            instance.subtotal = subtotal
            # model.save() recomputes tax_amount, total, due_amount

        instance.save()
        self._sync_bank(instance)
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
        business = require_business(self.context["request"])
        original_sale = data.get("original_sale")
        if original_sale is not None and original_sale.business_id != business.id:
            raise serializers.ValidationError({"original_sale": "Invalid sale for this business."})
        for item in data.get("items", []):
            sale_item = item.get("sale_item")
            product = item.get("product")
            if sale_item is not None and sale_item.sale.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid sale item for this business."})
            if product is not None and product.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid product for this business."})
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
                Product.objects.filter(pk=item.product_id).update(
                    stock_quantity=F("stock_quantity") + item.quantity
                )

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

    def validate(self, data):
        business = require_business(self.context["request"])
        customer = data.get("customer")
        if customer is not None and customer.business_id != business.id:
            raise serializers.ValidationError({"customer": "Invalid customer for this business."})
        return data
