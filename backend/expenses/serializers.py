from rest_framework import serializers
from bewosai.utils import require_business, sync_bank_transaction
from bewosai.validators import IMAGE_VALIDATORS
from .models import ExpenseCategory, Expense


class ExpenseCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ExpenseCategory
        fields = ("id", "name", "expense_type")
        read_only_fields = ("id",)


class ExpenseSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    receipt_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Expense
        fields = (
            "id", "category", "category_name", "amount", "date",
            "description", "payment_method", "bank_account", "bank_account_name",
            "receipt_image", "receipt_image_url", "created_at",
        )
        read_only_fields = ("id", "created_at", "category_name", "receipt_image_url", "bank_account_name")
        extra_kwargs = {"receipt_image": {"validators": IMAGE_VALIDATORS}}

    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True, default="")

    def validate(self, data):
        business = require_business(self.context["request"])
        bank_account = data.get("bank_account")
        if bank_account is not None and bank_account.business_id != business.id:
            raise serializers.ValidationError({"bank_account": "Invalid account for this business."})
        method = data.get("payment_method", getattr(self.instance, "payment_method", Expense.METHOD_CASH))
        if method == Expense.METHOD_CASH:
            data["bank_account"] = None      # cash never touches an account
        return data

    @staticmethod
    def _sync_bank(expense):
        """The expense's debit on its account — none for cash, or once deleted."""
        sync_bank_transaction(
            reference=f"EXPENSE-{expense.id}",
            bank_account=None if expense.is_deleted or expense.payment_method == Expense.METHOD_CASH
            else expense.bank_account,
            transaction_type="DEBIT",
            amount=expense.amount,
            date=expense.date,
            description=f"Expense: {expense.description or (expense.category.name if expense.category_id else '')}"[:500],
            created_by=expense.created_by,
        )

    def create(self, validated_data):
        expense = super().create(validated_data)
        self._sync_bank(expense)
        return expense

    def update(self, instance, validated_data):
        expense = super().update(instance, validated_data)
        self._sync_bank(expense)
        return expense

    def get_receipt_image_url(self, obj):
        if not obj.receipt_image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.receipt_image.url)
        return obj.receipt_image.url
