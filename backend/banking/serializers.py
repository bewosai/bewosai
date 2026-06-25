from rest_framework import serializers
from .models import BankAccount, BankTransaction


class BankAccountSerializer(serializers.ModelSerializer):
    balance = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)

    class Meta:
        model = BankAccount
        fields = (
            "id", "account_name", "bank_name", "account_number",
            "account_type", "opening_balance", "balance", "is_active", "created_at",
        )
        read_only_fields = ("id", "balance", "created_at")


class BankTransactionSerializer(serializers.ModelSerializer):
    account_name = serializers.CharField(source="account.account_name", read_only=True)

    class Meta:
        model = BankTransaction
        fields = (
            "id", "account", "account_name", "transaction_type",
            "amount", "date", "description", "reference", "created_at",
        )
        read_only_fields = ("id", "created_at", "account_name")
