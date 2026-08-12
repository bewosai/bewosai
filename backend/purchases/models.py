from django.db import models
from accounts.models import Business, User
from parties.models import Party
from inventory.models import Product


class Purchase(models.Model):
    STATUS_DRAFT = "DRAFT"
    STATUS_CONFIRMED = "CONFIRMED"
    STATUS_CANCELLED = "CANCELLED"
    STATUS_CHOICES = [
        (STATUS_DRAFT, "Draft"),
        (STATUS_CONFIRMED, "Confirmed"),
        (STATUS_CANCELLED, "Cancelled"),
    ]
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

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="purchases")
    bill_number = models.CharField(max_length=50)
    supplier = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, related_name="purchases")
    purchase_date = models.DateField()
    due_date = models.DateField(null=True, blank=True)
    subtotal = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0, help_text="VAT % e.g. 13")
    tax_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    paid_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    bank_account = models.ForeignKey(
        "banking.BankAccount", on_delete=models.SET_NULL, null=True, blank=True,
        related_name="purchases",
        help_text="Which account paid_amount was paid from when payment_method is non-cash — "
                   "a matching BankTransaction is kept in sync automatically.",
    )
    reconciled_amount = models.DecimalField(
        max_digits=14, decimal_places=2, default=0,
        help_text="Portion of paid_amount applied here later via a party PartyPayment "
                   "(see PartyPaymentListCreateView._reconcile_payment), as opposed to "
                   "being paid at the point of purchase. Lets the party ledger show each "
                   "rupee exactly once instead of double-counting reconciled payments.",
    )
    due_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    payment_method = models.CharField(max_length=10, choices=METHOD_CHOICES, default=METHOD_CASH)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default=STATUS_CONFIRMED)
    notes = models.TextField(blank=True)
    bill_image = models.ImageField(upload_to="purchases/bills/", null=True, blank=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("business", "bill_number")
        ordering = ["-purchase_date", "-created_at"]

    def __str__(self):
        return self.bill_number

    def save(self, *args, **kwargs):
        # tax_amount is computed from taxable amount (subtotal - discount),
        # mirroring Sale.save() so purchases carry VAT the same way sales do.
        from decimal import Decimal
        taxable = self.subtotal - self.discount
        if taxable < 0:
            taxable = 0
        self.tax_amount = (taxable * self.tax_rate / Decimal("100")).quantize(Decimal("0.01"))
        self.total = taxable + self.tax_amount
        self.due_amount = self.total - self.paid_amount
        super().save(*args, **kwargs)


class PurchaseItem(models.Model):
    purchase = models.ForeignKey(Purchase, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True)
    product_name = models.CharField(max_length=200)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=14, decimal_places=2)

    def save(self, *args, **kwargs):
        self.total = (self.quantity * self.unit_price) - self.discount_amount
        super().save(*args, **kwargs)


class PurchaseReturn(models.Model):
    original_purchase = models.ForeignKey(Purchase, on_delete=models.CASCADE, related_name="returns")
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="purchase_returns")
    return_date = models.DateField()
    reason = models.TextField(blank=True)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-return_date"]
