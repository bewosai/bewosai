from decimal import Decimal
from django.db import transaction
from django.db.models import F, Sum
from django.db.models.functions import Greatest
from rest_framework import serializers
from bewosai.validators import IMAGE_VALIDATORS, check_discounts
from bewosai.utils import require_business, sync_bank_transaction
from inventory.models import Product
from .models import Purchase, PurchaseItem, PurchaseReturn, PurchaseReturnItem


class PurchaseItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )
    # Nepal customs/VAT classification code, shown on the printed Tax
    # Invoice — sourced from the product since it isn't duplicated onto
    # every PurchaseItem row.
    product_hs_code = serializers.CharField(source="product.hs_code", read_only=True, default="")
    # The product's unit config, so a saved bill can still show the
    # primary/secondary unit toggle even though PurchaseItem itself only
    # stores which one this line was billed in (unit_label) — mirrors
    # sales/serializers.py's SaleItemSerializer.
    product_unit_name = serializers.CharField(source="product.unit.name", read_only=True, default="")
    product_unit_secondary = serializers.CharField(source="product.unit.secondary_unit", read_only=True, default="")
    product_unit_conversion_factor = serializers.SerializerMethodField()

    def get_product_unit_conversion_factor(self, obj):
        if obj.product and obj.product.unit:
            return obj.product.unit.conversion_factor
        return None

    class Meta:
        model = PurchaseItem
        fields = ["id", "product", "product_name", "product_hs_code", "product_unit_name", "product_unit_secondary",
                  "product_unit_conversion_factor", "quantity", "unit_label", "base_quantity", "unit_price",
                  "discount_amount", "total"]
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
                  "payment_method", "bank_account", "cash_amount", "status", "notes", "bill_image", "bill_image_url",
                  "is_deleted", "items", "created_at"]
        read_only_fields = ["tax_amount", "total", "due_amount", "created_at", "bill_image_url",
                            "supplier_name", "supplier_phone", "supplier_pan", "supplier_address"]
        extra_kwargs = {"bill_image": {"validators": IMAGE_VALIDATORS}}

    def validate(self, data):
        business = require_business(self.context["request"])
        supplier = data.get("supplier")
        if supplier is not None and supplier.business_id != business.id:
            raise serializers.ValidationError({"supplier": "Invalid supplier for this business."})
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        if data.get("payment_method") == Purchase.METHOD_SPLIT:
            if not bank_account:
                raise serializers.ValidationError({"bank_account": "Select which account the bank portion of a split payment should hit."})
            cash_amount = data.get("cash_amount") or Decimal("0")
            paid_amount = data.get("paid_amount") or Decimal("0")
            if cash_amount < 0 or cash_amount > paid_amount:
                raise serializers.ValidationError({"cash_amount": "Cash amount must be between 0 and the total amount paid."})
        for item in data.get("items", []):
            product = item.get("product")
            if product is not None and product.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid product for this business."})
        check_discounts(
            data.get("items"), data.get("discount"),
            fallback_subtotal=self.instance.subtotal if self.instance is not None else None,
        )
        return data

    @staticmethod
    def _set_base_quantity(item):
        if item.product_id and item.product.unit_id:
            item.base_quantity = item.product.unit.base_quantity_for(item.quantity, item.unit_label)
        else:
            item.base_quantity = item.quantity

    @staticmethod
    def _sync_bank(purchase):
        # A SPLIT payment only banks the non-cash remainder — the cash
        # portion (purchase.cash_amount) never touches the bank account.
        if purchase.payment_method == Purchase.METHOD_SPLIT:
            bank_amount = purchase.paid_amount - purchase.cash_amount
        elif purchase.payment_method != "CASH":
            bank_amount = purchase.paid_amount
        else:
            bank_amount = 0
        sync_bank_transaction(
            reference=f"PURCHASE-{purchase.id}",
            bank_account=purchase.bank_account if purchase.payment_method != "CASH" else None,
            transaction_type="DEBIT",
            amount=bank_amount,
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


class PurchaseReturnItemSerializer(serializers.ModelSerializer):
    purchase_item = serializers.PrimaryKeyRelatedField(
        queryset=PurchaseItem.objects.all(), required=False, allow_null=True
    )
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = PurchaseReturnItem
        fields = ("id", "purchase_item", "product", "product_name", "quantity", "unit_price", "total")
        read_only_fields = ("id", "total")


class PurchaseReturnSerializer(serializers.ModelSerializer):
    original_purchase_number = serializers.CharField(
        source="original_purchase.bill_number", read_only=True
    )
    items = PurchaseReturnItemSerializer(many=True, required=False)

    class Meta:
        model = PurchaseReturn
        fields = ["id", "original_purchase", "original_purchase_number", "return_date", "reason", "amount",
                  "refund_method", "bank_account", "refunded_amount", "items", "created_at"]
        read_only_fields = ["id", "created_at", "original_purchase_number", "refunded_amount"]

    def validate(self, data):
        business = require_business(self.context["request"])
        original_purchase = data.get("original_purchase")
        if original_purchase is not None and original_purchase.business_id != business.id:
            raise serializers.ValidationError({"original_purchase": "Invalid purchase for this business."})
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        if data.get("refund_method") == PurchaseReturn.METHOD_BANK and not bank_account:
            raise serializers.ValidationError({"bank_account": "Select which account received this refund."})
        for item in data.get("items", []):
            purchase_item = item.get("purchase_item")
            product = item.get("product")
            if purchase_item is not None and purchase_item.purchase.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid purchase item for this business."})
            if product is not None and product.business_id != business.id:
                raise serializers.ValidationError({"items": "Invalid product for this business."})
            qty = item.get("quantity") or Decimal("0")
            if purchase_item:
                already_returned = PurchaseReturnItem.objects.filter(purchase_item=purchase_item).aggregate(
                    total=Sum("quantity")
                )["total"] or Decimal("0")
                remaining = purchase_item.quantity - already_returned
                if qty > remaining:
                    raise serializers.ValidationError(
                        f"Cannot return {qty} of '{purchase_item.product_name}' — only "
                        f"{remaining} remaining from this bill."
                    )
        return data

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        original_purchase = validated_data["original_purchase"]

        # Mirrors SaleReturnSerializer.create exactly, direction reversed: a
        # return first reduces what we still owe the supplier (already
        # handled by parties.balances.party_balances — not touched here, to
        # avoid double-counting it). Only the part beyond what was actually
        # due is money the supplier actually has to pay back to us now.
        due_before = original_purchase.due_amount if original_purchase.due_amount > 0 else Decimal("0")
        refunded_amount = max(Decimal("0"), validated_data["amount"] - due_before)
        validated_data["refunded_amount"] = refunded_amount

        with transaction.atomic():
            purchase_return = PurchaseReturn.objects.create(**validated_data)

            for item_data in items_data:
                item = PurchaseReturnItem(purchase_return=purchase_return, **item_data)
                item.save()                     # computes item.total = qty*price

                # Goods going back to the supplier come out of stock — the
                # opposite of SaleReturnItem, which restores it. Floored at 0
                # (Greatest) so a stock discrepancy can't push it negative.
                # Converted into primary-unit terms the same way the original
                # purchase was (via Unit.base_quantity_for) — item.quantity is
                # whatever unit the returned line was originally billed in
                # (e.g. "Piece"), which isn't necessarily the primary unit
                # stock_quantity is tracked in (e.g. "Box").
                if item.product_id:
                    product = item.product
                    unit_label = item.purchase_item.unit_label if item.purchase_item_id else ""
                    base_qty = product.unit.base_quantity_for(item.quantity, unit_label) if product.unit_id else item.quantity
                    Product.objects.filter(pk=item.product_id).update(
                        stock_quantity=Greatest(F("stock_quantity") - base_qty, Decimal("0"))
                    )

            # A bank refund gets a real BankTransaction (money coming IN this
            # time); a cash refund is picked up directly by the cash reports.
            if refunded_amount > 0 and purchase_return.refund_method == PurchaseReturn.METHOD_BANK:
                sync_bank_transaction(
                    reference=f"PURCHASERETURN-{purchase_return.id}",
                    bank_account=purchase_return.bank_account,
                    transaction_type="CREDIT",
                    amount=refunded_amount,
                    date=purchase_return.return_date,
                    description=f"Refund for return on {original_purchase.bill_number}",
                    created_by=purchase_return.created_by,
                )

        return purchase_return
