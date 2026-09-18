from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product
from parties.models import Party
from purchases.models import Purchase, PurchaseItem
from sales.models import Sale, SaleItem


def D(x):
    return Decimal(str(x))


class ReturnsFlowTests(TestCase):
    """Sales Return (goods come back, stock restored) and Purchase Return (goods go
    back to the supplier, stock reduced) — the API the app's return screens call."""

    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=D(100), purchase_price=D(60), stock_quantity=D(10),
        )
        self.customer = Party.objects.create(business=self.business, name="Ram")
        self.supplier = Party.objects.create(business=self.business, name="Supplier", party_type="SUPPLIER")

    # ── helpers ──────────────────────────────────────────────────────────
    def make_sale(self, qty=5, price=100, discount=0, paid=0):
        sale = Sale.objects.create(
            business=self.business, customer=self.customer, invoice_number="S1", sale_date=date(2026, 9, 1),
            subtotal=D(qty * price - discount), paid_amount=D(paid),
        )
        item = SaleItem.objects.create(
            sale=sale, product=self.product, product_name="Rice", quantity=D(qty), unit_price=D(price),
            discount_amount=D(discount),
        )
        return sale, item

    def make_purchase(self, qty=8, price=60):
        purchase = Purchase.objects.create(
            business=self.business, supplier=self.supplier, bill_number="P1", purchase_date=date(2026, 9, 1),
            subtotal=D(qty * price),
        )
        item = PurchaseItem.objects.create(
            purchase=purchase, product=self.product, product_name="Rice", quantity=D(qty), unit_price=D(price),
        )
        return purchase, item

    def sale_return(self, sale, item, qty, price=100, amount=None):
        return self.api.post("/api/sales/returns/", {
            "original_sale": sale.id, "return_date": "2026-09-05", "reason": "Damaged",
            "amount": str(amount if amount is not None else qty * price),
            "items": [{"sale_item": item.id, "product": self.product.id, "product_name": "Rice",
                       "quantity": str(qty), "unit_price": str(price)}],
        }, format="json")

    def purchase_return(self, purchase, item, qty, price=60):
        return self.api.post("/api/purchases/returns/", {
            "original_purchase": purchase.id, "return_date": "2026-09-05", "reason": "Wrong item",
            "amount": str(qty * price),
            "items": [{"purchase_item": item.id, "product": self.product.id, "product_name": "Rice",
                       "quantity": str(qty), "unit_price": str(price)}],
        }, format="json")

    def stock(self):
        self.product.refresh_from_db()
        return self.product.stock_quantity

    # ── sales return ─────────────────────────────────────────────────────
    def test_sales_return_restores_stock_and_is_listed(self):
        sale, item = self.make_sale(qty=5)
        res = self.sale_return(sale, item, 2)
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(self.stock(), D(12))            # 10 + 2 back
        listed = self.api.get("/api/sales/returns/")
        self.assertEqual(listed.status_code, 200)
        rows = listed.data.get("results", listed.data)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["items"][0]["sale_item"], item.id)     # the app uses this to work out what's left

    def test_cannot_return_more_than_was_sold_across_several_returns(self):
        sale, item = self.make_sale(qty=5)
        self.assertEqual(self.sale_return(sale, item, 3).status_code, 201)
        over = self.sale_return(sale, item, 3)             # only 2 left
        self.assertEqual(over.status_code, 400)
        self.assertIn("remaining", str(over.data))
        self.assertEqual(self.stock(), D(13))              # the rejected return changed nothing
        self.assertEqual(self.sale_return(sale, item, 2).status_code, 201)   # exactly what's left is fine

    def test_a_return_reduces_what_the_customer_owes(self):
        sale, item = self.make_sale(qty=5, paid=0)         # owes 500
        self.assertEqual(self.customer.balance, D(500))
        self.sale_return(sale, item, 2)                    # 200 back
        self.assertEqual(self.customer.balance, D(300))

    def test_returning_a_discounted_line_at_the_price_actually_paid(self):
        # 5 x 100 with a 50 discount = 450 paid, i.e. 90 a unit.
        sale, item = self.make_sale(qty=5, price=100, discount=50)
        self.assertEqual(self.sale_return(sale, item, 2, price=90).status_code, 201)
        self.assertEqual(self.customer.balance, D(450) - D(180))

    def test_a_return_against_another_business_is_refused(self):
        other_owner = User.objects.create_user(email="other@example.com", name="Other")
        other = Business.objects.create(owner=other_owner, name="Other Shop")
        StaffMember.objects.create(user=other_owner, business=other, role=StaffMember.ROLE_OWNER)
        sale, item = self.make_sale(qty=5)
        client = APIClient(HTTP_X_BUSINESS_ID=str(other.id))
        client.force_authenticate(other_owner)
        res = client.post("/api/sales/returns/", {
            "original_sale": sale.id, "return_date": "2026-09-05", "amount": "100",
            "items": [{"sale_item": item.id, "product": self.product.id, "product_name": "Rice",
                       "quantity": "1", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(self.stock(), D(10))

    # ── purchase return ──────────────────────────────────────────────────
    def test_purchase_return_reduces_stock(self):
        purchase, item = self.make_purchase(qty=8)
        res = self.purchase_return(purchase, item, 3)
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(self.stock(), D(7))               # 10 - 3 sent back

    def test_purchase_return_cannot_exceed_what_was_bought(self):
        purchase, item = self.make_purchase(qty=8)
        self.assertEqual(self.purchase_return(purchase, item, 6).status_code, 201)
        over = self.purchase_return(purchase, item, 3)     # only 2 left
        self.assertEqual(over.status_code, 400)
        self.assertEqual(self.stock(), D(4))

    def test_a_return_reduces_what_we_owe_the_supplier(self):
        purchase, item = self.make_purchase(qty=8, price=60)      # owe 480
        self.assertEqual(self.supplier.balance, D(-480))
        self.purchase_return(purchase, item, 3)                    # 180 back
        self.assertEqual(self.supplier.balance, D(-300))

    def test_purchase_return_stock_never_goes_negative(self):
        self.product.stock_quantity = D(1)
        self.product.save()
        purchase, item = self.make_purchase(qty=8)
        self.assertEqual(self.purchase_return(purchase, item, 5).status_code, 201)
        self.assertEqual(self.stock(), D(0))
