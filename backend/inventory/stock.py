"""
The one place that moves stock for sales and purchases.

Only a CONFIRMED document moves stock: a draft doesn't, and cancelling or
deleting a confirmed one puts its effect back (restoring it from the Recycle
Bin applies it again). Quantities are each line's base_quantity — the amount
in the product's main unit (6 Pieces of a 12-Piece Box = 0.5) — snapshotted
when the line was saved, so undoing uses exactly what was applied. Services
never carry stock. Taking stock never goes below zero (the existing rule).
"""
from decimal import Decimal

from django.db.models import F
from django.db.models.functions import Greatest

from .models import Product

CONFIRMED = "CONFIRMED"


def _qty(item):
    return item.base_quantity if item.base_quantity is not None else item.quantity


def _change(items, direction):
    for item in items:
        if not item.product_id:
            continue
        stockable = Product.objects.filter(pk=item.product_id, item_type=Product.PRODUCT)
        if direction > 0:
            stockable.update(stock_quantity=F("stock_quantity") + _qty(item))
        else:
            stockable.update(stock_quantity=Greatest(F("stock_quantity") - _qty(item), Decimal("0")))


def apply_sale(items):
    """A confirmed sale's lines leave stock."""
    _change(items, -1)


def undo_sale(items):
    _change(items, +1)


def apply_purchase(items):
    """A confirmed purchase's lines come into stock."""
    _change(items, +1)


def undo_purchase(items):
    _change(items, -1)
