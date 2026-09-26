from django.core.validators import MinValueValidator
from django.db import models
from accounts.models import Business, User


class Category(models.Model):
    business = models.ForeignKey(
        Business, on_delete=models.CASCADE, related_name="categories"
    )
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("business", "name")
        verbose_name_plural = "categories"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Unit(models.Model):
    """
    Primary unit e.g. Box (bx).
    Optional secondary e.g. Piece with conversion_factor:
    1 primary = conversion_factor secondary (1 Box = 12 Pieces).
    """
    business = models.ForeignKey(
        Business, on_delete=models.CASCADE, related_name="units"
    )
    name = models.CharField(max_length=50)
    abbreviation = models.CharField(max_length=10, blank=True)
    secondary_unit = models.CharField(max_length=50, blank=True)
    secondary_abbreviation = models.CharField(max_length=10, blank=True)
    conversion_factor = models.DecimalField(
        max_digits=10,
        decimal_places=4,
        null=True,
        blank=True,
        help_text="e.g. 12 means 1 Box = 12 Pieces",
    )

    class Meta:
        unique_together = ("business", "name")
        ordering = ["name"]

    def __str__(self):
        if self.secondary_unit and self.conversion_factor:
            return f"{self.name} ({self.conversion_factor} {self.secondary_unit})"
        return self.name

    @property
    def display(self):
        if self.secondary_unit:
            return f"{self.name}/{self.secondary_unit}"
        return self.name

    def base_quantity_for(self, quantity, unit_label):
        """
        Converts a quantity billed in `unit_label` into primary-unit terms,
        for stock tracking (stock_quantity is always kept in the primary
        unit). Only converts when unit_label matches this Unit's configured
        secondary unit — anything else (blank, or the primary unit's own
        name) passes the quantity through unchanged.
        """
        if unit_label and self.secondary_unit and self.conversion_factor:
            if unit_label.strip().lower() == self.secondary_unit.strip().lower():
                return quantity / self.conversion_factor
        return quantity


class Product(models.Model):
    """
    Item form:
      name, category (+ add new), item_type (Product|Service),
      unit (primary/secondary/conversion),
      sale_price, purchase_price,
      Product only: opening stock (stock_quantity), low_stock_threshold
      Service: stock disabled (forced to 0 on save)
    """
    PRODUCT = "PRODUCT"
    SERVICE = "SERVICE"
    ITEM_TYPE_CHOICES = [
        (PRODUCT, "Product"),
        (SERVICE, "Service"),
    ]

    business = models.ForeignKey(
        Business, on_delete=models.CASCADE, related_name="products"
    )
    name = models.CharField(max_length=200)
    category = models.ForeignKey(
        Category, on_delete=models.SET_NULL, null=True, blank=True
    )
    item_type = models.CharField(
        max_length=20,
        choices=ITEM_TYPE_CHOICES,
        default=PRODUCT,
        db_index=True,
        help_text="PRODUCT tracks stock; SERVICE does not",
    )
    unit = models.ForeignKey(
        Unit, on_delete=models.SET_NULL, null=True, blank=True
    )
    description = models.TextField(blank=True)

    purchase_price = models.DecimalField(
        max_digits=12, decimal_places=2, default=0, validators=[MinValueValidator(0)]
    )
    sale_price = models.DecimalField(
        max_digits=12, decimal_places=2, default=0, validators=[MinValueValidator(0)]
    )
    # Prices per *secondary* unit (e.g. per Piece when the unit is Box = 12
    # Pieces). Optional: blank means "primary price ÷ conversion_factor", which
    # is what billing used before these existed; set them when a loose piece
    # sells (or is bought) at its own rate.
    secondary_purchase_price = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(0)]
    )
    secondary_sale_price = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(0)]
    )

    # Stock — PRODUCT only (SERVICE forced to 0 in save())
    stock_quantity = models.DecimalField(
        max_digits=12, decimal_places=3, default=0, validators=[MinValueValidator(0)]
    )
    low_stock_threshold = models.DecimalField(
        max_digits=12, decimal_places=3, default=5, validators=[MinValueValidator(0)]
    )
    min_stock_level = models.DecimalField(
        max_digits=12, decimal_places=3, default=0, validators=[MinValueValidator(0)]
    )

    barcode = models.CharField(max_length=100, blank=True)
    hs_code = models.CharField(
        max_length=20, blank=True,
        help_text="Harmonized System code — Nepal customs/VAT classification, shown on some tax invoices.",
    )
    image = models.ImageField(upload_to="products/", null=True, blank=True)
    is_active = models.BooleanField(default=True)
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        indexes = [
            models.Index(fields=["business", "item_type"]),
            models.Index(fields=["business", "is_deleted"]),
        ]

    def __str__(self):
        return f"{self.name} ({self.get_item_type_display()})"

    @property
    def is_product(self):
        return self.item_type == self.PRODUCT

    @property
    def is_service(self):
        return self.item_type == self.SERVICE

    @property
    def is_low_stock(self):
        if self.item_type == self.SERVICE:
            return False
        return self.stock_quantity <= self.low_stock_threshold

    def save(self, *args, **kwargs):
        if self.item_type == self.SERVICE:
            self.stock_quantity = 0
            self.low_stock_threshold = 0
            self.min_stock_level = 0
        super().save(*args, **kwargs)


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

    product = models.ForeignKey(
        Product, on_delete=models.CASCADE, related_name="movements"
    )
    movement_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    note = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.product.name} {self.movement_type} {self.quantity}"