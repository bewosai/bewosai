from rest_framework import serializers
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
            "description", "payment_method", "receipt_image", "receipt_image_url", "created_at",
        )
        read_only_fields = ("id", "created_at", "category_name", "receipt_image_url")

    def get_receipt_image_url(self, obj):
        if not obj.receipt_image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.receipt_image.url)
        return obj.receipt_image.url
