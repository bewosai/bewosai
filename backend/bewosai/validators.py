"""
Shared validation for uploaded images (bill photos, receipts, product images,
bank QR codes, business logos).

A cap is needed because phone cameras produce files well past what image
hosting accepts (Cloudinary's free plan refuses anything over 10 MB), and
without one an oversized upload surfaces as an opaque 500 from the storage
backend instead of a message the user can act on.
"""
from decimal import Decimal

from django.core.validators import validate_image_file_extension
from rest_framework import serializers

MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MB — well under hosting limits, plenty for a bill photo


def validate_image_size(file):
    size = getattr(file, "size", None)
    if size is not None and size > MAX_IMAGE_BYTES:
        raise serializers.ValidationError(
            f"This image is {size / (1024 * 1024):.1f} MB — please use one under "
            f"{MAX_IMAGE_BYTES // (1024 * 1024)} MB."
        )


# Passed as `validators` in a ModelSerializer's extra_kwargs, which *replaces*
# the model field's own validators — so the extension check is repeated here.
IMAGE_VALIDATORS = [validate_image_file_extension, validate_image_size]


# ── Discounts ─────────────────────────────────────────────────────────────────

_TOLERANCE = Decimal("0.01")  # clients round to paisa; don't reject a discount equal to the total by a rounding hair


def check_discounts(items, invoice_discount, *, fallback_subtotal=None):
    """Reject discounts that make no sense: negative, or bigger than what they
    discount. Works on validated data (Decimals) for a sale, purchase or quotation.

    - items: list of validated item dicts (quantity, unit_price, discount_amount), or
      None when the request doesn't carry items (a partial update).
    - invoice_discount: the invoice-level discount, or None if not being set.
    - fallback_subtotal: what the invoice-level discount is measured against when
      `items` is None (the stored subtotal on an update, or a quotation's own subtotal).

    Raises serializers.ValidationError keyed by field, so the client can show it
    next to the right input instead of a server error. Without this a negative
    discount silently raised the total and an oversized one gave negative line totals.
    """
    errors = {}
    items_net = None

    if items is not None:
        items_net = Decimal("0")
        for item in items:
            discount = item.get("discount_amount") or Decimal("0")
            gross = (item.get("quantity") or Decimal("0")) * (item.get("unit_price") or Decimal("0"))
            if discount < 0:
                errors["items"] = "An item's discount can't be negative."
                break
            if discount > gross + _TOLERANCE:
                errors["items"] = (
                    f"An item's discount (Rs {discount}) can't be more than its "
                    f"quantity × price (Rs {gross})."
                )
                break
            items_net += gross - discount

    if invoice_discount is not None:
        if invoice_discount < 0:
            errors["discount"] = "Discount can't be negative."
        else:
            basis = items_net if items_net is not None else fallback_subtotal
            if basis is not None and invoice_discount > basis + _TOLERANCE:
                errors["discount"] = f"Discount (Rs {invoice_discount}) can't be more than the subtotal (Rs {basis})."

    if errors:
        raise serializers.ValidationError(errors)
