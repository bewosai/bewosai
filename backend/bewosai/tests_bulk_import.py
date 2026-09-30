"""Excel bulk import: every row checked on its own, a preview that saves nothing,
and bad rows skipped with their Excel row number and a plain reason."""
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from billing.services import _extend_and_grant
from inventory.models import Category, Product, Unit
from parties.models import Party


class BulkImportTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O", is_verified=True)
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        _extend_and_grant(business=self.business, plan=Business.PLAN_PREMIUM, coupon_user=owner)  # import is Premium
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        Product.objects.create(business=self.business, name="Rice")
        Party.objects.create(business=self.business, name="Ram")

    def products(self, rows, dry_run=False):
        res = self.api.post("/api/inventory/products/bulk-import/", {"products": rows, "dry_run": dry_run}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        return res.data

    PRODUCT_ROWS = [
        {"name": "Soap", "category": "Toiletries", "unit": "Box", "sale_price": "1,200", "purchase_price": 1000,
         "secondary_sale_price": "110", "stock_quantity": "5"},
        {"name": "rice", "sale_price": 50},                    # already exists (case-insensitive)
        {"name": "Oil", "sale_price": "abc"},                  # not a number
        {"name": "Salt", "purchase_price": -5},                # negative
        {"name": "", "sale_price": 10},                        # no name
        {"name": "Soap", "sale_price": 1},                     # twice in the file
        {"name": "Sugar", "sale_price": "", "low_stock_threshold": ""},
    ]

    def test_preview_marks_each_row_and_saves_nothing(self):
        data = self.products(self.PRODUCT_ROWS, dry_run=True)
        statuses = [(r["row"], r["status"]) for r in data["results"]]
        self.assertEqual(statuses, [(2, "ready"), (3, "skipped"), (4, "skipped"), (5, "skipped"),
                                    (6, "skipped"), (7, "skipped"), (8, "ready")])
        self.assertEqual((data["ready"], data["skipped"], data["created"]), (2, 5, 0))
        reasons = {r["row"]: r["reason"] for r in data["results"] if r["status"] == "skipped"}
        self.assertEqual(reasons[3], 'A product named "rice" already exists')
        self.assertEqual(reasons[4], 'Sale price must be a number (got "abc")')
        self.assertEqual(reasons[5], "Purchase price can't be negative")
        self.assertEqual(reasons[6], "Missing name")
        self.assertEqual(reasons[7], '"Soap" appears more than once in this file')
        # Nothing saved — not even the category/unit the file mentions.
        self.assertFalse(Product.objects.filter(name="Soap").exists())
        self.assertFalse(Category.objects.filter(name="Toiletries").exists())
        self.assertFalse(Unit.objects.filter(business=self.business, name="Box").exists())

    def test_import_creates_the_good_rows_and_skips_the_rest(self):
        data = self.products(self.PRODUCT_ROWS)
        self.assertEqual((data["created"], data["skipped"]), (2, 5))
        soap = Product.objects.get(business=self.business, name="Soap")
        self.assertEqual(soap.sale_price, Decimal("1200"))
        self.assertEqual(soap.secondary_sale_price, Decimal("110"))
        self.assertIsNone(soap.secondary_purchase_price)
        self.assertEqual((soap.category.name, soap.unit.name), ("Toiletries", "Box"))
        sugar = Product.objects.get(business=self.business, name="Sugar")
        self.assertEqual((sugar.sale_price, sugar.low_stock_threshold), (Decimal("0"), Decimal("5")))
        # Older clients read skipped_details; the row and reason are still there.
        self.assertEqual(data["skipped_details"][0]["reason"], 'A product named "rice" already exists')
        self.assertEqual(data["skipped_details"][0]["excel_row"], 3)

    def test_party_import_checks_type_email_and_allows_to_give_balances(self):
        rows = [
            {"name": "Sita", "party_type": "supplier", "email": "sita@example.com", "opening_balance": "-2,500"},
            {"name": "RAM", "party_type": "CUSTOMER"},                    # already exists
            {"name": "Hari", "party_type": "VENDOR"},                     # unknown type
            {"name": "Gita", "email": "not-an-email"},                    # bad email
            {"name": "Mohan"},                                            # defaults to CUSTOMER
        ]
        preview = self.api.post("/api/parties/bulk-import/", {"parties": rows, "dry_run": True}, format="json").data
        self.assertEqual([r["status"] for r in preview["results"]], ["ready", "skipped", "skipped", "skipped", "ready"])
        self.assertEqual(Party.objects.filter(business=self.business).count(), 1)

        data = self.api.post("/api/parties/bulk-import/", {"parties": rows}, format="json").data
        self.assertEqual((data["created"], data["skipped"]), (2, 3))
        sita = Party.objects.get(business=self.business, name="Sita")
        self.assertEqual((sita.party_type, sita.opening_balance), ("SUPPLIER", Decimal("-2500")))
        self.assertEqual(Party.objects.get(business=self.business, name="Mohan").party_type, "CUSTOMER")
        reasons = [r.get("reason") for r in data["results"]]
        self.assertIn('Party type "VENDOR" is not one of CUSTOMER, SUPPLIER or BOTH', reasons)
        self.assertIn('"not-an-email" is not a valid email address', reasons)

    def test_too_many_rows_is_refused_with_a_clear_message(self):
        res = self.api.post("/api/inventory/products/bulk-import/",
                            {"products": [{"name": f"P{i}"} for i in range(501)]}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("limited to 500 rows", res.data["error"])
