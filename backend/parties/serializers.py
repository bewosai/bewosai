from rest_framework import serializers
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
            "payment_method", "date", "note", "created_at",
        )
        read_only_fields = ("id", "created_at", "party_name")
