from django.db import models
from accounts.models import Business, User


class ExpenseCategory(models.Model):
    TYPE_DAILY = "DAILY"
    TYPE_PURCHASE = "PURCHASE"
    TYPE_UTILITY = "UTILITY"
    TYPE_STAFF = "STAFF"
    TYPE_OTHER = "OTHER"
    TYPE_CHOICES = [
        (TYPE_DAILY, "Daily"),
        (TYPE_PURCHASE, "Purchase"),
        (TYPE_UTILITY, "Utility"),
        (TYPE_STAFF, "Staff"),
        (TYPE_OTHER, "Other"),
    ]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="expense_categories")
    name = models.CharField(max_length=100)
    expense_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_OTHER)

    class Meta:
        unique_together = ("business", "name")
        verbose_name_plural = "expense categories"

    def __str__(self):
        return self.name


class Expense(models.Model):
    METHOD_CASH = "CASH"
    METHOD_BANK = "BANK"
    METHOD_CHOICES = [(METHOD_CASH, "Cash"), (METHOD_BANK, "Bank")]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="expenses")
    category = models.ForeignKey(ExpenseCategory, on_delete=models.SET_NULL, null=True, blank=True)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    date = models.DateField()
    description = models.TextField(blank=True)
    payment_method = models.CharField(max_length=10, choices=METHOD_CHOICES, default=METHOD_CASH)
    receipt_image = models.ImageField(upload_to="expenses/receipts/", null=True, blank=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.date} – {self.amount}"
