from rest_framework import serializers
from bewosai.utils import require_business, sync_bank_transaction
from .models import Party, PartyPayment


class PartySerializer(serializers.ModelSerializer):
    balance = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)

    class Meta:
        model = Party
        fields = (
            "id", "name", "party_type", "customer_type", "phone", "email", "address",
            "pan_number", "vat_number",
            "opening_balance", "balance", "notes", "is_active", "created_at",
        )
        read_only_fields = ("id", "balance", "created_at")


class PartyPaymentSerializer(serializers.ModelSerializer):
    party_name = serializers.CharField(source="party.name", read_only=True)

    class Meta:
        model = PartyPayment
        fields = (
            "id", "party", "party_name", "payment_type", "amount",
            "payment_method", "bank_account", "date", "note", "created_at",
        )
        read_only_fields = ("id", "created_at", "party_name")

    def validate(self, data):
        business = require_business(self.context["request"])
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        return data

    @staticmethod
    def _sync_bank(payment):
        sync_bank_transaction(
            reference=f"PARTYPAYMENT-{payment.id}",
            bank_account=payment.bank_account if payment.payment_method != "CASH" else None,
            transaction_type="CREDIT" if payment.payment_type == "IN" else "DEBIT",
            amount=payment.amount,
            date=payment.date,
            description=f"{'Received from' if payment.payment_type == 'IN' else 'Paid to'} {payment.party.name}",
            created_by=payment.created_by,
        )
