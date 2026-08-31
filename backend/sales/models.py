from django.db import models
from accounts.models import Business, User
from parties.models import Party
from inventory.models import Product


class Sale(models.Model):
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

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="sales")
    invoice_number = models.CharField(max_length=50)
    customer = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True, related_name="sales")
    sale_date = models.DateField()
    due_date = models.DateField(null=True, blank=True)
    subtotal = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0, help_text="VAT % e.g. 13")
    tax_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    paid_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    bank_account = models.ForeignKey(
        "banking.BankAccount", on_delete=models.SET_NULL, null=True, blank=True,
        related_name="sales",
        help_text="Which account received paid_amount when payment_method is non-cash — "
                   "a matching BankTransaction is kept in sync automatically.",
    )
    reminder_enabled = models.BooleanField(default=False)
    reminder_at = models.DateTimeField(
        null=True, blank=True,
        help_text="When to notify the business owner to follow up on this due amount. "
                   "Fired as an on-device notification by the mobile app, not a server push.",
    )
    reconciled_amount = models.DecimalField(
        max_digits=14, decimal_places=2, default=0,
        help_text="Portion of paid_amount applied here later via a party PartyPayment "
                   "(see PartyPaymentListCreateView._reconcile_payment), as opposed to "
                   "being paid at the point of sale. Lets the party ledger show each "
                   "rupee exactly once instead of double-counting reconciled payments.",
    )
    due_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    payment_method = models.CharField(max_length=10, choices=METHOD_CHOICES, default=METHOD_CASH)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default=STATUS_CONFIRMED)
    notes = models.TextField(blank=True)
    sale_type = models.CharField(max_length=10, choices=[('SALE', 'Sale'), ('CHALLAN', 'Delivery Challan'), ('QUOTATION', 'Quotation')], default='SALE')
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("business", "invoice_number")
        ordering = ["-sale_date", "-created_at"]

    def __str__(self):
        return self.invoice_number

    def save(self, *args, **kwargs):
        # tax_amount is computed from taxable amount (subtotal - discount)
        taxable = self.subtotal - self.discount
        if taxable < 0:
            taxable = 0
        from decimal import Decimal
        self.tax_amount = (taxable * self.tax_rate / Decimal("100")).quantize(Decimal("0.01"))
        self.total = taxable + self.tax_amount
        self.due_amount = self.total - self.paid_amount
        super().save(*args, **kwargs)


class SaleItem(models.Model):
    sale = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True)
    product_name = models.CharField(max_length=200)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    unit_cost = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
        help_text="Snapshot of product.purchase_price at the time of sale, so editing a "
                   "product's cost later doesn't retroactively rewrite past profit reports.",
    )
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=14, decimal_places=2)

    def save(self, *args, **kwargs):
        self.total = (self.quantity * self.unit_price) - self.discount_amount
        if self.unit_cost is None and self.product_id:
            self.unit_cost = self.product.purchase_price
        super().save(*args, **kwargs)


class SaleReturn(models.Model):
    original_sale = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="returns")
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="sale_returns")
    return_date = models.DateField()
    reason = models.TextField(blank=True)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-return_date"]


class SaleReturnItem(models.Model):
    sale_return = models.ForeignKey(SaleReturn, on_delete=models.CASCADE, related_name="items")
    sale_item = models.ForeignKey(SaleItem, on_delete=models.SET_NULL, null=True, related_name="return_items")
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True)
    product_name = models.CharField(max_length=200)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    total = models.DecimalField(max_digits=14, decimal_places=2)

    def save(self, *args, **kwargs):
        self.total = self.quantity * self.unit_price
        super().save(*args, **kwargs)


class Quotation(models.Model):
    STATUS_DRAFT = "DRAFT"
    STATUS_SENT = "SENT"
    STATUS_ACCEPTED = "ACCEPTED"
    STATUS_REJECTED = "REJECTED"
    STATUS_CHOICES = [
        (STATUS_DRAFT, "Draft"),
        (STATUS_SENT, "Sent"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_REJECTED, "Rejected"),
    ]

    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="quotations")
    quotation_number = models.CharField(max_length=50)
    customer = models.ForeignKey(Party, on_delete=models.SET_NULL, null=True, blank=True)
    date = models.DateField()
    expiry_date = models.DateField(null=True, blank=True)
    subtotal = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default=STATUS_DRAFT)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-date"]
