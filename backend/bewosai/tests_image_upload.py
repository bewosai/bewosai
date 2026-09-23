"""
Uploaded images: a normal photo is accepted, an oversized or non-image file is
rejected with a message the user can act on (a 400, never a 500 from storage),
and leaving the image out still works.
"""
import io

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase
from PIL import Image

from accounts.serializers import BusinessSerializer
from banking.serializers import BankAccountSerializer
from bewosai.validators import MAX_IMAGE_BYTES, validate_image_size
from expenses.serializers import ExpenseSerializer
from inventory.serializers import ProductSerializer
from purchases.serializers import PurchaseSerializer


def png(size=(40, 40), name="bill.png"):
    buf = io.BytesIO()
    Image.new("RGB", size, "white").save(buf, "PNG")
    return SimpleUploadedFile(name, buf.getvalue(), content_type="image/png")


def oversized_png():
    """A real, valid PNG padded past the limit (trailing bytes don't break decoding)."""
    f = png(name="huge.png")
    data = f.read() + b"\0" * (MAX_IMAGE_BYTES + 1024)
    return SimpleUploadedFile("huge.png", data, content_type="image/png")


# (serializer class, image field name)
IMAGE_FIELDS = [
    (ExpenseSerializer, "receipt_image"),
    (PurchaseSerializer, "bill_image"),
    (ProductSerializer, "image"),
    (BankAccountSerializer, "qr_code"),
    (BusinessSerializer, "logo"),
]


class ImageSizeValidatorTests(SimpleTestCase):
    def test_under_the_limit_passes(self):
        validate_image_size(png())

    def test_over_the_limit_says_how_big_and_what_to_do(self):
        from rest_framework.exceptions import ValidationError
        with self.assertRaises(ValidationError) as ctx:
            validate_image_size(oversized_png())
        message = str(ctx.exception.detail[0])
        self.assertIn("MB", message)
        self.assertIn("under 5 MB", message)


class EveryImageFieldIsGuardedTests(SimpleTestCase):
    def field_errors(self, serializer_cls, field, upload):
        ser = serializer_cls(data={field: upload})
        ser.is_valid()
        return ser.errors.get(field)

    def test_a_normal_image_is_accepted_by_every_field(self):
        for cls, field in IMAGE_FIELDS:
            with self.subTest(field=field):
                self.assertIsNone(self.field_errors(cls, field, png()))

    def test_an_oversized_image_is_rejected_by_every_field(self):
        for cls, field in IMAGE_FIELDS:
            with self.subTest(field=field):
                errors = self.field_errors(cls, field, oversized_png())
                self.assertTrue(errors, f"{cls.__name__}.{field} accepted an oversized image")
                self.assertIn("under 5 MB", str(errors[0]))

    def test_a_non_image_is_still_rejected_by_every_field(self):
        for cls, field in IMAGE_FIELDS:
            with self.subTest(field=field):
                text = SimpleUploadedFile("notes.txt", b"not an image", content_type="text/plain")
                self.assertTrue(self.field_errors(cls, field, text))

    def test_leaving_the_image_out_is_fine(self):
        for cls, field in IMAGE_FIELDS:
            with self.subTest(field=field):
                self.assertFalse(cls().fields[field].required)
