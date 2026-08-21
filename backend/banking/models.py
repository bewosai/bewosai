from django.db import models
from accounts.models import Business, User


class BankAccount(models.Model):
    TYPE_CASH           = "CASH"
    TYPE_BANK           = "BANK"
    TYPE_ESEWA          = "ESEWA"
    TYPE_KHALTI         = "KHALTI"
    TYPE_CONNECT_IPS    = "CONNECT_IPS"
    TYPE_IME_PAY        = "IME_PAY"
    TYPE_MOBILE_BANKING = "MOBILE_BANKING"
    TYPE_OTHER          = "OTHER"
    TYPE_CHOICES = [
        (TYPE_CASH,           "Cash"),
        (TYPE_BANK,           "Bank"),
        (TYPE_ESEWA,          "eSewa"),
        (TYPE_KHALTI,         "Khalti"),
        (TYPE_CONNECT_IPS,    "Connect IPS"),
        (TYPE_IME_PAY,        "IME Pay"),
        (TYPE_MOBILE_BANKING, "Mobile Banking"),
        (TYPE_OTHER,          "Other"),
    ]

    # How many active accounts of a given type one business may have —
    # types not listed here (Cash, IME Pay, Mobile Banking, Other) are
    # unlimited. A business realistically has at most a couple of bank
    # accounts but only one login for a given wallet/payment gateway.
    TYPE_LIMITS = {
        TYPE_BANK: 2,
        TYPE_ESEWA: 1,
        TYPE_KHALTI: 1,
        TYPE_CONNECT_IPS: 1,
    }

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="bank_accounts")
    account_name = models.CharField(max_length=150)
    bank_name = models.CharField(max_length=150, blank=True)
    account_number = models.CharField(max_length=50, blank=True)
    account_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_CASH)
    opening_balance = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    qr_code = models.ImageField(upload_to="banking/qr/", null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

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
