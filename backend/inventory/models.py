from django.db import models
from accounts.models import Business, User


class Category(models.Model):
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="categories")
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("business", "name")
        verbose_name_plural = "categories"

    def __str__(self):
        return self.name


class Unit(models.Model):
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="units")
    name = models.CharField(max_length=50)                     # primary unit e.g. "Box"
    abbreviation = models.CharField(max_length=10, blank=True) # e.g. "bx"
    # Secondary (sub) unit — e.g. "Piece" inside a Box
    secondary_unit = models.CharField(max_length=50, blank=True)
    secondary_abbreviation = models.CharField(max_length=10, blank=True)
    conversion_factor = models.DecimalField(           # how many secondary per 1 primary
        max_digits=10, decimal_places=4, null=True, blank=True,
        help_text="e.g. 12 means 1 Box = 12 Pieces",
    )

    class Meta:
        unique_together = ("business", "name")

    def __str__(self):
        if self.secondary_unit and self.conversion_factor:
            return f"{self.name} ({self.conversion_factor} {self.secondary_unit})"
        return self.name

    @property
    def display(self):
        if self.secondary_unit:
            return f"{self.name}/{self.secondary_unit}"
        return self.name


class Product(models.Model):
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="products")
    name = models.CharField(max_length=200)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    unit = models.ForeignKey(Unit, on_delete=models.SET_NULL, null=True, blank=True)
    description = models.TextField(blank=True)
    purchase_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    sale_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    stock_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    low_stock_threshold = models.DecimalField(max_digits=12, decimal_places=3, default=5)
    barcode = models.CharField(max_length=100, blank=True)
    image = models.ImageField(upload_to="products/", null=True, blank=True)
    min_stock_level = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    is_active = models.BooleanField(default=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    @property
    def is_low_stock(self):
        return self.stock_quantity <= self.low_stock_threshold


class StockMovement(models.Model):
    STOCK_IN = "IN"
    STOCK_OUT = "OUT"
    ADJUSTMENT = "ADJUSTMENT"
    DAMAGE = "DAMAGE"
    LOST = "LOST"
    TRANSFER = "TRANSFER"
    OPENING = "OPENING"
    TYPE_CHOICES = [
        (STOCK_IN, "Stock In"),
        (STOCK_OUT, "Stock Out"),
        (ADJUSTMENT, "Adjustment"),
        (DAMAGE, "Damage"),
        (LOST, "Lost"),
        (TRANSFER, "Transfer"),
        (OPENING, "Opening Stock"),
    ]

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="movements")
    movement_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    note = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
