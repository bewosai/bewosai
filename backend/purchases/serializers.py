from decimal import Decimal
from django.db.models import F
from django.db.models.functions import Greatest
from rest_framework import serializers
from bewosai.utils import require_business, sync_bank_transaction
from inventory.models import Product
from .models import Purchase, PurchaseItem, PurchaseReturn


class PurchaseItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )
    # Nepal customs/VAT classification code, shown on the printed Tax
    # Invoice — sourced from the product since it isn't duplicated onto
    # every PurchaseItem row.
    product_hs_code = serializers.CharField(source="product.hs_code", read_only=True, default="")

    class Meta:
        model = PurchaseItem
        fields = ["id", "product", "product_name", "product_hs_code", "quantity", "unit_label", "base_quantity", "unit_price", "discount_amount", "total"]
        read_only_fields = ["id", "total", "base_quantity"]


class PurchaseSerializer(serializers.ModelSerializer):
    items = PurchaseItemSerializer(many=True, required=False)
    bill_number      = serializers.CharField(required=False, allow_blank=True)
    supplier_name    = serializers.CharField(source="supplier.name", read_only=True)
    supplier_phone   = serializers.CharField(source="supplier.phone", read_only=True, default="")
    supplier_pan     = serializers.CharField(source="supplier.pan_number", read_only=True, default="")
    supplier_address = serializers.CharField(source="supplier.address", read_only=True, default="")
    bill_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Purchase
        fields = ["id", "bill_number", "supplier", "supplier_name", "supplier_phone", "supplier_pan",
                  "supplier_address", "purchase_date", "due_date",
                  "subtotal", "discount", "tax_rate", "tax_amount", "total", "paid_amount", "due_amount",
                  "payment_method", "bank_account", "status", "notes", "bill_image", "bill_image_url",
                  "is_deleted", "items", "created_at"]
        read_only_fields = ["tax_amount", "total", "due_amount", "created_at", "bill_image_url",
                            "supplier_name", "supplier_phone", "supplier_pan", "supplier_address"]

    def validate(self, data):
        business = require_business(self.context["request"])
        supplier = data.get("supplier")
        if supplier is not None and supplier.business_id != business.id:
            raise serializers.ValidationError({"supplier": "Invalid supplier for this business."})
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        for item in data.get("items", []):
            product = item.get("product")
            if product is not None and product.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid product for this business."})
        return data

    @staticmethod
    def _set_base_quantity(item):
        if item.product_id and item.product.unit_id:
            item.base_quantity = item.product.unit.base_quantity_for(item.quantity, item.unit_label)
        else:
            item.base_quantity = item.quantity

    @staticmethod
    def _sync_bank(purchase):
        sync_bank_transaction(
            reference=f"PURCHASE-{purchase.id}",
            bank_account=purchase.bank_account if purchase.payment_method != "CASH" else None,
            transaction_type="DEBIT",
            amount=purchase.paid_amount,
            date=purchase.purchase_date,
            description=f"Purchase {purchase.bill_number}" + (f" — {purchase.supplier.name}" if purchase.supplier_id else ""),
            created_by=purchase.created_by,
        )

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
            self._set_base_quantity(item)
            item.save()                     # computes item.total
            subtotal += item.total
            if item.product_id:
                Product.objects.filter(pk=item.product_id).update(
                    stock_quantity=F("stock_quantity") + item.base_quantity
                )
        purchase.subtotal = subtotal
        purchase.save()                     # model.save() recomputes tax_amount, total, due_amount
        self._sync_bank(purchase)
        return purchase

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Reverse old stock increments before replacing items — using the
        # original base_quantity snapshot, not a fresh conversion.
        if items_data is not None:
            for old_item in instance.items.all():
                if old_item.product_id:
                    reverse_qty = old_item.base_quantity if old_item.base_quantity is not None else old_item.quantity
                    Product.objects.filter(pk=old_item.product_id).update(
                        stock_quantity=Greatest(F("stock_quantity") - reverse_qty, Decimal("0"))
                    )
            instance.items.all().delete()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if items_data is not None:
            subtotal = Decimal("0")
            for item_data in items_data:
                item = PurchaseItem(purchase=instance, **item_data)
                self._set_base_quantity(item)
                item.save()
                subtotal += item.total
                if item.product_id:
                    Product.objects.filter(pk=item.product_id).update(
                        stock_quantity=F("stock_quantity") + item.base_quantity
                    )
            instance.subtotal = subtotal
            # model.save() recomputes tax_amount, total, due_amount

        instance.save()
        self._sync_bank(instance)
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

    def validate(self, data):
        business = require_business(self.context["request"])
        original_purchase = data.get("original_purchase")
        if original_purchase is not None and original_purchase.business_id != business.id:
            raise serializers.ValidationError({"original_purchase": "Invalid purchase for this business."})
        return data
