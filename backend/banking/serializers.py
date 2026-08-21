from rest_framework import serializers
from bewosai.utils import require_business
from .models import BankAccount, BankTransaction


class BankAccountSerializer(serializers.ModelSerializer):
    balance = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)
    qr_code_url = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = BankAccount
        fields = (
            "id", "account_name", "bank_name", "account_number",
            "account_type", "opening_balance", "qr_code", "qr_code_url",
            "balance", "is_active", "created_at",
        )
        read_only_fields = ("id", "balance", "created_at", "qr_code_url")

    def validate_account_type(self, value):
        limit = BankAccount.TYPE_LIMITS.get(value)
        if limit is None:
            return value
        business = require_business(self.context["request"])
        existing = BankAccount.objects.filter(business=business, account_type=value, is_active=True)
        if self.instance is not None:
            existing = existing.exclude(pk=self.instance.pk)
        if existing.count() >= limit:
            label = dict(BankAccount.TYPE_CHOICES).get(value, value)
            noun = "account" if limit == 1 else "accounts"
            raise serializers.ValidationError(
                f"You can only have {limit} {label} {noun}. Remove or deactivate one first."
            )
        return value

    def get_qr_code_url(self, obj):
        if obj.qr_code:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.qr_code.url)
            return obj.qr_code.url
        return None


class BankTransactionSerializer(serializers.ModelSerializer):
    account_name = serializers.CharField(source="account.account_name", read_only=True)

    class Meta:
        model = BankTransaction
        fields = (
            "id", "account", "account_name", "transaction_type",
            "amount", "date", "description", "reference", "created_at",
        )
        read_only_fields = ("id", "created_at", "account_name")
