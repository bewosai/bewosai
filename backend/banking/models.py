from django.db import models
from accounts.models import Business, User


class BankAccount(models.Model):
    TYPE_SAVINGS = "SAVINGS"
    TYPE_CURRENT = "CURRENT"
    TYPE_CASH = "CASH"
    TYPE_CHOICES = [
        (TYPE_SAVINGS, "Savings"),
        (TYPE_CURRENT, "Current"),
        (TYPE_CASH, "Cash"),
    ]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="bank_accounts")
    account_name = models.CharField(max_length=150)
    bank_name = models.CharField(max_length=150, blank=True)
    account_number = models.CharField(max_length=50, blank=True)
    account_type = models.CharField(max_length=15, choices=TYPE_CHOICES, default=TYPE_CURRENT)
    opening_balance = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.account_name} ({self.bank_name})"

    @property
    def balance(self):
        credits = self.transactions.filter(transaction_type="CREDIT").aggregate(
            t=models.Sum("amount")
        )["t"] or 0
        debits = self.transactions.filter(transaction_type="DEBIT").aggregate(
            t=models.Sum("amount")
        )["t"] or 0
        return self.opening_balance + credits - debits


class BankTransaction(models.Model):
    CREDIT = "CREDIT"
    DEBIT = "DEBIT"
    TYPE_CHOICES = [(CREDIT, "Credit"), (DEBIT, "Debit")]

    account = models.ForeignKey(BankAccount, on_delete=models.CASCADE, related_name="transactions")
    transaction_type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    date = models.DateField()
    description = models.TextField(blank=True)
    reference = models.CharField(max_length=100, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]
