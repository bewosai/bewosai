from rest_framework import serializers
from .models import ExpenseCategory, Expense


class ExpenseCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ExpenseCategory
        fields = ("id", "name", "expense_type")
        read_only_fields = ("id",)


class ExpenseSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)

    class Meta:
        model = Expense
        fields = (
            "id", "category", "category_name", "amount", "date",
            "description", "payment_method", "receipt_image", "created_at",
        )
        read_only_fields = ("id", "created_at", "category_name")
