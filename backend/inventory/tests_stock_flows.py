"""
Stock must follow what really happened, through every action a shop takes:
only a CONFIRMED sale/purchase moves stock (a draft doesn't), editing moves
the difference, cancelling or deleting puts it back, restoring from the
Recycle Bin takes it again — in the product's main unit, also when a line is
billed in the secondary unit (Box of 12 → Pieces). And "low stock" counts only
real products, never services.
"""
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product, Unit


class StockFlowTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        self.today = timezone.localdate().isoformat()
        self.rice = Product.objects.create(business=self.business, name="Rice", stock_quantity=Decimal("50"),
                                           low_stock_threshold=Decimal("5"), sale_price=Decimal("100"))
        box = Unit.objects.create(business=self.business, name="Box", secondary_unit="Piece",
                                  conversion_factor=Decimal("12"))
        self.soap = Product.objects.create(business=self.business, name="Soap", unit=box,
                                           stock_quantity=Decimal("10"), sale_price=Decimal("1200"))

    def stock(self, product):
        product.refresh_from_db()
        return product.stock_quantity

    def sell(self, qty, status="CONFIRMED", product=None, unit_label=""):
        product = product or self.rice
        res = self.api.post("/api/sales/", {
            "invoice_number": f"INV-{Product.objects.count()}-{qty}-{status}-{unit_label}",
            "sale_date": self.today, "payment_method": "CASH", "paid_amount": "0", "status": status,
            "items": [{"product": product.id, "product_name": product.name, "quantity": str(qty),
                       "unit_label": unit_label, "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    def buy(self, qty, status="CONFIRMED"):
        res = self.api.post("/api/purchases/", {
            "bill_number": f"P-{qty}-{status}", "purchase_date": self.today, "payment_method": "CASH",
            "paid_amount": "0", "status": status,
            "items": [{"product": self.rice.id, "product_name": "Rice", "quantity": str(qty), "unit_price": "80"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    # ── sales ──
    def test_a_confirmed_sale_takes_stock_and_a_draft_does_not(self):
        self.sell(8)
        self.assertEqual(self.stock(self.rice), Decimal("42"))
        self.sell(5, status="DRAFT")
        self.assertEqual(self.stock(self.rice), Decimal("42"))

    def test_editing_a_sale_moves_only_the_difference(self):
        sale = self.sell(8)
        self.api.patch(f"/api/sales/{sale}/", {"items": [
            {"product": self.rice.id, "product_name": "Rice", "quantity": "3", "unit_price": "100"}]}, format="json")
        self.assertEqual(self.stock(self.rice), Decimal("47"))

    def test_cancelling_a_sale_puts_the_stock_back(self):
        sale = self.sell(8)
        self.assertEqual(self.api.patch(f"/api/sales/{sale}/", {"status": "CANCELLED"}, format="json").status_code, 200)
        self.assertEqual(self.stock(self.rice), Decimal("50"))

    def test_confirming_a_draft_takes_the_stock_then(self):
        sale = self.sell(6, status="DRAFT")
        self.api.patch(f"/api/sales/{sale}/", {"status": "CONFIRMED"}, format="json")
        self.assertEqual(self.stock(self.rice), Decimal("44"))

    def test_deleting_a_sale_puts_stock_back_and_restoring_takes_it_again(self):
        sale = self.sell(8)
        self.assertEqual(self.api.delete(f"/api/sales/{sale}/").status_code, 204)
        self.assertEqual(self.stock(self.rice), Decimal("50"))
        res = self.api.post(f"/api/purchases/recycle-bin/restore/sale/{sale}/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.stock(self.rice), Decimal("42"))

    def test_selling_pieces_of_a_box_takes_the_box_fraction_and_gives_it_back(self):
        sale = self.sell(6, product=self.soap, unit_label="Piece")   # 6 pieces = half a box
        self.assertEqual(self.stock(self.soap), Decimal("9.5"))
        self.api.delete(f"/api/sales/{sale}/")
        self.assertEqual(self.stock(self.soap), Decimal("10"))

    # ── purchases ──
    def test_a_confirmed_purchase_adds_stock_and_a_draft_does_not(self):
        self.buy(20)
        self.assertEqual(self.stock(self.rice), Decimal("70"))
        self.buy(7, status="DRAFT")
        self.assertEqual(self.stock(self.rice), Decimal("70"))

    def test_cancelling_or_deleting_a_purchase_takes_its_stock_back_out(self):
        first, second = self.buy(20), self.buy(10)
        self.assertEqual(self.stock(self.rice), Decimal("80"))
        self.api.patch(f"/api/purchases/{first}/", {"status": "CANCELLED"}, format="json")
        self.assertEqual(self.stock(self.rice), Decimal("60"))
        self.api.delete(f"/api/purchases/{second}/")
        self.assertEqual(self.stock(self.rice), Decimal("50"))
        self.api.post(f"/api/purchases/recycle-bin/restore/purchase/{second}/")
        self.assertEqual(self.stock(self.rice), Decimal("60"))

    # ── low stock ──
    def test_low_stock_counts_real_products_only(self):
        Product.objects.create(business=self.business, name="Repair", item_type=Product.SERVICE)
        self.sell(46)                                           # Rice: 50 → 4, below its alert level of 5
        dashboard = self.api.get("/api/reports/dashboard/").data
        self.assertEqual(dashboard["low_stock_count"], 1)
        low = self.api.get("/api/inventory/products/", {"low_stock": "true"}).data
        low = low["results"] if isinstance(low, dict) else low
        self.assertEqual([p["name"] for p in low], ["Rice"])
        report = self.api.get("/api/reports/inventory/").data
        self.assertEqual(report["low_stock_count"], 1)
