"""
Discounts must make sense on the server whatever the client sends: never
negative, never bigger than what they discount — for sales, purchases and
quotations, on create and on update.
"""
from datetime import date
from decimal import Decimal

from django.test import SimpleTestCase, TestCase
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from bewosai.validators import check_discounts
from inventory.models import Product
from parties.models import Party
from sales.models import Sale


def D(x):
    return Decimal(str(x))


def item(qty, price, discount=0):
    return {"quantity": D(qty), "unit_price": D(price), "discount_amount": D(discount)}


class CheckDiscountsTests(SimpleTestCase):
    def errors(self, *args, **kw):
        with self.assertRaises(ValidationError) as ctx:
            check_discounts(*args, **kw)
        return ctx.exception.detail

    def test_valid_discounts_pass(self):
        check_discounts([item(2, 100, 20)], D(50))       # invoice discount within the 180 subtotal
        check_discounts([item(2, 100)], D(200))          # exactly the whole subtotal
        check_discounts([item(2, 100, 200)], None)       # exactly the whole line
        check_discounts(None, None)

    def test_negative_item_discount_is_rejected(self):
        self.assertIn("items", self.errors([item(1, 100, -5)], None))

    def test_item_discount_over_its_line_is_rejected(self):
        errors = self.errors([item(2, 100, 250)], None)
        self.assertIn("more than its quantity", str(errors["items"]))

    def test_negative_invoice_discount_is_rejected(self):
        self.assertIn("discount", self.errors([item(1, 100)], D(-1)))

    def test_invoice_discount_over_the_subtotal_is_rejected(self):
        # the subtotal is what the items add up to *after* their own discounts
        errors = self.errors([item(2, 100, 50)], D(151))
        self.assertIn("more than the subtotal", str(errors["discount"]))

    def test_a_rounding_hair_over_is_allowed(self):
        check_discounts([item(3, "33.33")], D("99.98"))   # subtotal 99.99, client rounded oddly

    def test_without_items_it_uses_the_stored_subtotal(self):
        check_discounts(None, D(50), fallback_subtotal=D(100))
        self.assertIn("discount", self.errors(None, D(101), fallback_subtotal=D(100)))
        check_discounts(None, D(999))                     # nothing to compare against: not this check's call


class DiscountApiTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=D(100), purchase_price=D(60), stock_quantity=D(50),
        )
        self.customer = Party.objects.create(business=self.business, name="Ram")
        self.supplier = Party.objects.create(business=self.business, name="Sup", party_type="SUPPLIER")

    def sale_payload(self, discount=0, item_discount=0, qty=2, price=100):
        return {
            "invoice_number": "INV-1", "customer": self.customer.id, "sale_date": "2026-09-21",
            "discount": str(discount), "tax_rate": "0", "paid_amount": "0", "payment_method": "CASH",
            "items": [{"product": self.product.id, "product_name": "Rice", "quantity": str(qty),
                       "unit_price": str(price), "discount_amount": str(item_discount)}],
        }

    def test_a_sensible_sale_is_saved(self):
        res = self.api.post("/api/sales/", self.sale_payload(discount=20, item_discount=10), format="json")
        self.assertEqual(res.status_code, 201, res.content)
        sale = Sale.objects.get()
        self.assertEqual((sale.subtotal, sale.discount, sale.total), (D(190), D(20), D(170)))

    def test_discount_bigger_than_the_subtotal_is_a_400_and_nothing_is_saved(self):
        res = self.api.post("/api/sales/", self.sale_payload(discount=500), format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("discount", res.json())
        self.assertFalse(Sale.objects.exists())

    def test_negative_discount_cannot_raise_the_total(self):
        res = self.api.post("/api/sales/", self.sale_payload(discount=-50), format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(Sale.objects.exists())

    def test_item_discount_over_the_line_is_a_400(self):
        res = self.api.post("/api/sales/", self.sale_payload(item_discount=999), format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("items", res.json())

    def test_editing_a_sale_is_checked_too(self):
        created = self.api.post("/api/sales/", self.sale_payload(), format="json").json()
        res = self.api.patch(f"/api/sales/{created['id']}/", {"discount": "5000"}, format="json")
        self.assertEqual(res.status_code, 400, res.content)
        self.assertIn("discount", res.json())

    def test_purchase_discounts_are_checked(self):
        payload = {
            "bill_number": "B-1", "supplier": self.supplier.id, "purchase_date": "2026-09-21",
            "discount": "9999", "tax_rate": "0", "paid_amount": "0", "payment_method": "CASH",
            "items": [{"product": self.product.id, "product_name": "Rice", "quantity": "2",
                       "unit_price": "60", "discount_amount": "0"}],
        }
        res = self.api.post("/api/purchases/", payload, format="json")
        self.assertEqual(res.status_code, 400, res.content)
        self.assertIn("discount", res.json())
        payload["discount"] = "20"
        self.assertEqual(self.api.post("/api/purchases/", payload, format="json").status_code, 201)

    def test_quotation_discount_is_checked(self):
        base = {"customer": self.customer.id, "date": "2026-09-21", "subtotal": "1000", "total": "900", "status": "DRAFT"}
        bad = self.api.post("/api/sales/quotations/", {**base, "discount": "2000"}, format="json")
        self.assertEqual(bad.status_code, 400, bad.content)
        self.assertIn("discount", bad.json())
        neg = self.api.post("/api/sales/quotations/", {**base, "discount": "-1"}, format="json")
        self.assertEqual(neg.status_code, 400)
        ok = self.api.post("/api/sales/quotations/", {**base, "discount": "100"}, format="json")
        self.assertEqual(ok.status_code, 201, ok.content)
