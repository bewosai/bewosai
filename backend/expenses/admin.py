from django.contrib import admin
from .models import ExpenseCategory, Expense

admin.site.register(ExpenseCategory)


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ("business", "category", "amount", "date", "payment_method")
    list_filter = ("payment_method", "category__expense_type")
