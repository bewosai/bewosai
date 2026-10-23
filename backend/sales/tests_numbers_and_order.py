"""
Invoice, bill and quotation numbers never repeat inside a business — not even
as "inv-0005 " vs "INV-0005" — and party and item names come back A–Z
ignoring capitals.
"""
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product
from parties.models import Party
from sales.models import Quotation, Sale


class NumbersAndOrderTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        self.today = timezone.localdate().isoformat()

    def sell(self, number):
        return self.api.post("/api/sales/", {
            "invoice_number": number, "sale_date": self.today, "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "1", "unit_price": "100"}],
        }, format="json")

    def buy(self, number):
        return self.api.post("/api/purchases/", {
            "bill_number": number, "purchase_date": self.today, "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "1", "unit_price": "60"}],
        }, format="json")

    def test_invoice_number_cannot_repeat_in_any_spelling(self):
        self.assertEqual(self.sell("INV-0005").status_code, 201)
        for again in ("INV-0005", "inv-0005", " INV-0005 "):
            res = self.sell(again)
            self.assertEqual(res.status_code, 400, again)
            self.assertIn("already exists", str(res.data))
        self.assertEqual(Sale.objects.count(), 1)

    def test_number_is_saved_without_spaces_and_editing_keeps_it(self):
        res = self.sell("  INV-0009 ")
        self.assertEqual(res.data["invoice_number"], "INV-0009")
        res = self.api.patch(f"/api/sales/{res.data['id']}/", {"invoice_number": "INV-0009", "notes": "x"},
                             format="json")
        self.assertEqual(res.status_code, 200, res.content)

    def test_bill_number_cannot_repeat(self):
        self.assertEqual(self.buy("B-1").status_code, 201)
        self.assertEqual(self.buy("b-1").status_code, 400)

    def test_quotation_numbers_are_unique(self):
        Quotation.objects.create(business=self.business, quotation_number="QUO-0002", date=self.today)
        Quotation.objects.create(business=self.business, quotation_number="QUO-0001", date=self.today)
        res = self.api.post("/api/sales/quotations/", {"date": self.today, "subtotal": "10", "total": "10"},
                            format="json")
        self.assertEqual(res.status_code, 201, res.content)
        numbers = list(Quotation.objects.values_list("quotation_number", flat=True))
        self.assertEqual(len(numbers), len(set(numbers)))

    def test_names_come_back_a_to_z_ignoring_capitals(self):
        for name in ("zebra traders", "Apple Store", "mango mart", "Banana"):
            Party.objects.create(business=self.business, name=name)
            Product.objects.create(business=self.business, name=name, sale_price=1)
        parties = self.api.get("/api/parties/").data
        parties = parties["results"] if isinstance(parties, dict) else parties
        self.assertEqual([p["name"] for p in parties], ["Apple Store", "Banana", "mango mart", "zebra traders"])
        products = self.api.get("/api/inventory/products/").data
        products = products["results"] if isinstance(products, dict) else products
        self.assertEqual([p["name"] for p in products], ["Apple Store", "Banana", "mango mart", "zebra traders"])
