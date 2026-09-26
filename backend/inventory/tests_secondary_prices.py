from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product, Unit


class SecondaryUnitPriceTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient()
        self.api.force_authenticate(owner)
        self.h = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        self.box = Unit.objects.create(
            business=self.business, name="Box", secondary_unit="Piece", conversion_factor=Decimal("12"),
        )

    def test_a_product_keeps_its_own_per_piece_prices(self):
        res = self.api.post("/api/inventory/products/", {
            "business": self.business.id, "name": "Soap", "unit": self.box.id,
            "purchase_price": "1000", "sale_price": "1200",
            "secondary_purchase_price": "90", "secondary_sale_price": "110",
        }, format="json", **self.h)
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(res.data["secondary_sale_price"], "110.00")
        self.assertEqual(res.data["secondary_purchase_price"], "90.00")

        # Clearing them goes back to "main price ÷ conversion".
        res = self.api.patch(f"/api/inventory/products/{res.data['id']}/", {
            "secondary_purchase_price": None, "secondary_sale_price": None,
        }, format="json", **self.h)
        self.assertEqual(res.status_code, 200, res.content)
        self.assertIsNone(res.data["secondary_sale_price"])

    def test_products_without_them_are_unchanged(self):
        product = Product.objects.create(business=self.business, name="Rice", sale_price=Decimal("50"))
        row = self.api.get(f"/api/inventory/products/{product.id}/", **self.h).data
        self.assertIsNone(row["secondary_sale_price"])
        self.assertEqual(row["sale_price"], "50.00")

    def test_a_negative_per_piece_price_is_refused(self):
        res = self.api.post("/api/inventory/products/", {
            "business": self.business.id, "name": "Oil", "unit": self.box.id,
            "sale_price": "100", "secondary_sale_price": "-5",
        }, format="json", **self.h)
        self.assertEqual(res.status_code, 400)
