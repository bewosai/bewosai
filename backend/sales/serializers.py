from decimal import Decimal
from django.db import transaction
from django.db.models import Sum, F
from django.db.models.functions import Greatest
from rest_framework import serializers
from bewosai.validators import check_discounts
from bewosai.utils import require_business, sync_bank_transaction
from inventory.models import Product
from .models import Sale, SaleItem, SaleReturn, SaleReturnItem, Quotation


class SaleItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )
    # Nepal customs/VAT classification code, shown on the printed Tax
    # Invoice — sourced from the product since it isn't (and shouldn't be)
    # duplicated onto every SaleItem row.
    product_hs_code = serializers.CharField(source="product.hs_code", read_only=True, default="")
    # The product's unit config, so a saved bill can still show the
    # primary/secondary unit toggle even though SaleItem itself only
    # stores which one this line was billed in (unit_label).
    product_unit_name = serializers.CharField(source="product.unit.name", read_only=True, default="")
    product_unit_secondary = serializers.CharField(source="product.unit.secondary_unit", read_only=True, default="")
    product_unit_conversion_factor = serializers.SerializerMethodField()

    def get_product_unit_conversion_factor(self, obj):
        if obj.product and obj.product.unit:
            return obj.product.unit.conversion_factor
        return None

    class Meta:
        model = SaleItem
        fields = ("id", "product", "product_name", "product_hs_code", "product_unit_name", "product_unit_secondary",
                  "product_unit_conversion_factor", "quantity", "unit_label", "base_quantity", "unit_price",
                  "unit_cost", "discount_amount", "total")
        read_only_fields = ("id", "unit_cost", "total", "base_quantity")


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
            "paid_amount", "due_amount", "payment_method", "bank_account", "cash_amount", "status", "sale_type",
            "reminder_enabled", "reminder_at", "reminder_note",
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
        if data.get("payment_method") == Sale.METHOD_SPLIT:
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
    def _sync_bank(sale):
        # A SPLIT payment only banks the non-cash remainder — the cash
        # portion (sale.cash_amount) never touches the bank account.
        if sale.payment_method == Sale.METHOD_SPLIT:
            bank_amount = sale.paid_amount - sale.cash_amount
        elif sale.payment_method != "CASH":
            bank_amount = sale.paid_amount
        else:
            bank_amount = 0
        sync_bank_transaction(
            reference=f"SALE-{sale.id}",
            bank_account=sale.bank_account if sale.payment_method != "CASH" else None,
            transaction_type="CREDIT",
            amount=bank_amount,
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
            self._set_base_quantity(item)
            item.save()                     # computes item.total = qty*price - discount
            subtotal += item.total

            # Decrement stock for linked products via an atomic F()-expression
            # UPDATE (not read-modify-write) so two concurrent sales of the
            # same product can't race and silently lose one decrement.
            # base_quantity is the primary-unit equivalent (see
            # Unit.base_quantity_for) — stock is always tracked in that unit.
            if item.product_id:
                Product.objects.filter(pk=item.product_id).update(
                    stock_quantity=Greatest(F("stock_quantity") - item.base_quantity, Decimal("0"))
                )

        sale.subtotal = subtotal
        # model.save() recomputes tax_amount, total, due_amount
        sale.save()
        self._sync_bank(sale)
        return sale

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Reverse old stock decrements before deleting items — using the
        # same base_quantity snapshot that was originally deducted (not a
        # fresh conversion), so a conversion_factor change on the product
        # since then can't throw stock off.
        if items_data is not None:
            for old_item in instance.items.all():
                if old_item.product_id:
                    reverse_qty = old_item.base_quantity if old_item.base_quantity is not None else old_item.quantity
                    Product.objects.filter(pk=old_item.product_id).update(
                        stock_quantity=F("stock_quantity") + reverse_qty
                    )
            instance.items.all().delete()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if items_data is not None:
            subtotal = Decimal("0")
            for item_data in items_data:
                item = SaleItem(sale=instance, **item_data)
                self._set_base_quantity(item)
                item.save()
                subtotal += item.total

                # Apply new stock decrements
                if item.product_id:
                    Product.objects.filter(pk=item.product_id).update(
                        stock_quantity=Greatest(F("stock_quantity") - item.base_quantity, Decimal("0"))
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
        fields = (
            "id", "original_sale", "invoice_number", "return_date", "reason", "amount",
            "refund_method", "bank_account", "refunded_amount", "items", "created_at",
        )
        read_only_fields = ("id", "created_at", "invoice_number", "refunded_amount")

    def validate(self, data):
        business = require_business(self.context["request"])
        original_sale = data.get("original_sale")
        if original_sale is not None and original_sale.business_id != business.id:
            raise serializers.ValidationError({"original_sale": "Invalid sale for this business."})
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        if data.get("refund_method") == SaleReturn.METHOD_BANK and not bank_account:
            raise serializers.ValidationError({"bank_account": "Select which account paid this refund."})
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
        original_sale = validated_data["original_sale"]

        # A return first reduces what the customer still owes on this invoice
        # (parties.balances.party_balances already subtracts the full return
        # `amount` from their balance — see SaleReturn's own docstring on
        # why this must NOT also touch original_sale.due_amount, which would
        # double-count it). Only the part beyond what was actually due is
        # real money that has to be handed back right now.
        due_before = original_sale.due_amount if original_sale.due_amount > 0 else Decimal("0")
        refunded_amount = max(Decimal("0"), validated_data["amount"] - due_before)
        validated_data["refunded_amount"] = refunded_amount

        with transaction.atomic():
            sale_return = SaleReturn.objects.create(**validated_data)

            for item_data in items_data:
                item = SaleReturnItem(sale_return=sale_return, **item_data)
                item.save()                     # computes item.total = qty*price

                # Restore stock for linked products, converted into primary-unit
                # terms the same way the original sale was (via
                # Unit.base_quantity_for) — item.quantity is whatever unit the
                # returned line was originally billed in (e.g. "Piece"), which
                # isn't necessarily the primary unit stock_quantity is tracked
                # in (e.g. "Box").
                if item.product_id:
                    product = item.product
                    unit_label = item.sale_item.unit_label if item.sale_item_id else ""
                    base_qty = product.unit.base_quantity_for(item.quantity, unit_label) if product.unit_id else item.quantity
                    Product.objects.filter(pk=item.product_id).update(
                        stock_quantity=F("stock_quantity") + base_qty
                    )

            # A bank refund needs a real BankTransaction so the account's balance
            # and Bank Statement reflect the money actually leaving it — a cash
            # refund has nowhere to sync to (there's no "cash" bank account) but
            # is picked up directly by the Cash Flow/Cash In Hand/Dashboard cash
            # figures instead (see reports.views._ACTUAL_CASH's sibling logic there).
            if refunded_amount > 0 and sale_return.refund_method == SaleReturn.METHOD_BANK:
                sync_bank_transaction(
                    reference=f"SALERETURN-{sale_return.id}",
                    bank_account=sale_return.bank_account,
                    transaction_type="DEBIT",
                    amount=refunded_amount,
                    date=sale_return.return_date,
                    description=f"Refund for return on {original_sale.invoice_number}",
                    created_by=sale_return.created_by,
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
        subtotal = data.get("subtotal", self.instance.subtotal if self.instance is not None else None)
        check_discounts(None, data.get("discount"), fallback_subtotal=subtotal)
        return data
