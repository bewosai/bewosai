from django.db import models
from accounts.models import Business, User


class Party(models.Model):
    TYPE_CUSTOMER = "CUSTOMER"
    TYPE_SUPPLIER = "SUPPLIER"
    TYPE_BOTH = "BOTH"
    TYPE_CHOICES = [
        (TYPE_CUSTOMER, "Customer"),
        (TYPE_SUPPLIER, "Supplier"),
        (TYPE_BOTH, "Both"),
    ]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="parties")
    name = models.CharField(max_length=200)
    party_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_CUSTOMER)
    customer_type = models.CharField(max_length=20, choices=[('RETAIL', 'Retail'), ('WHOLESALE', 'Wholesale'), ('DISTRIBUTOR', 'Distributor'), ('RESELLER', 'Reseller')], blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    pan_number = models.CharField(max_length=20, blank=True)
    vat_number = models.CharField(max_length=20, blank=True)
    opening_balance = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "parties"
        ordering = ["name"]

    def __str__(self):
        return self.name

    @property
    def balance(self):
        """
        Outstanding amount owed by (positive) or to (negative) this party.
        Sourced from Sale/Purchase.due_amount rather than the PartyPayment ledger,
        since due_amount is kept current by both sale/purchase creation and
        payment reconciliation (see PartyPaymentListCreateView._reconcile_payment),
        while PartyPayment rows alone miss dues never yet reconciled.
        """
        sales_due = self.sales.filter(
            status="CONFIRMED", is_deleted=False
        ).aggregate(total=models.Sum("due_amount"))["total"] or 0
        purchases_due = self.purchases.filter(
            status="CONFIRMED", is_deleted=False
        ).aggregate(total=models.Sum("due_amount"))["total"] or 0
        return self.opening_balance + sales_due - purchases_due


class PartyPayment(models.Model):
    PAY_IN = "IN"
    PAY_OUT = "OUT"
    TYPE_CHOICES = [(PAY_IN, "Received"), (PAY_OUT, "Paid")]

    METHOD_CASH   = "CASH"
    METHOD_BANK   = "BANK"
    METHOD_ESEWA  = "ESEWA"
    METHOD_KHALTI = "KHALTI"
    METHOD_CHOICES = [
        (METHOD_CASH,   "Cash"),
        (METHOD_BANK,   "Bank"),
        (METHOD_ESEWA,  "eSewa"),
        (METHOD_KHALTI, "Khalti"),
    ]

    party = models.ForeignKey(Party, on_delete=models.CASCADE, related_name="payments")
    payment_type = models.CharField(max_length=5, choices=TYPE_CHOICES)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    payment_method = models.CharField(max_length=10, choices=METHOD_CHOICES, default=METHOD_CASH)
    bank_account = models.ForeignKey(
        "banking.BankAccount", on_delete=models.SET_NULL, null=True, blank=True,
        related_name="party_payments",
        help_text="Required when payment_method is a non-cash method that should hit a real "
                   "account — a matching BankTransaction is kept in sync automatically.",
    )
    date = models.DateField()
    note = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]
