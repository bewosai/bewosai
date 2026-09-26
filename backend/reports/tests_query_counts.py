"""
Every list page must cost the same number of database queries whether it shows
1 row or many. Production talks to Postgres over the network, where each query
is a round trip — a page that ran a few queries per row (as Parties once did,
6 per party) took over a minute for a business with a hundred parties.
"""
from datetime import date
from decimal import Decimal

from django.db import connection
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import Business, StaffMember, User
from billing.services import _extend_and_grant
from expenses.models import Expense
from inventory.models import Product
from parties.models import Party
from purchases.models import Purchase
from sales.models import Sale

LIST_PAGES = [
    "/api/parties/",
    "/api/sales/",
    "/api/purchases/",
    "/api/expenses/",
    "/api/inventory/products/",
    "/api/parties/payments/",
    "/api/reports/dashboard/",
]


class ListPagesDoNotQueryPerRowTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="owner@example.com", name="Owner", is_verified=True)
        self.business = Business.objects.create(owner=owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        _extend_and_grant(business=self.business, plan="PREMIUM", coupon_user=owner)
        self.api = APIClient()
        token = RefreshToken.for_user(owner).access_token
        self.api.credentials(HTTP_AUTHORIZATION=f"Bearer {token}", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.rows = 0

    def add_rows(self, count):
        for _ in range(count):
            self.rows += 1
            n = self.rows
            party = Party.objects.create(business=self.business, name=f"Party {n}")
            Sale.objects.create(
                business=self.business, customer=party, invoice_number=f"INV-{n}", sale_date=date(2026, 9, 22),
                subtotal=Decimal("500"), total=Decimal("500"), paid_amount=Decimal("100"), status="CONFIRMED",
            )
            Purchase.objects.create(
                business=self.business, supplier=party, bill_number=f"P-{n}", purchase_date=date(2026, 9, 22),
                subtotal=Decimal("200"), total=Decimal("200"), status="CONFIRMED",
            )
            Expense.objects.create(business=self.business, amount=Decimal("50"), date=date(2026, 9, 22))
            Product.objects.create(business=self.business, name=f"Item {n}", sale_price=Decimal("10"))

    def query_counts(self):
        counts = {}
        for path in LIST_PAGES:
            with CaptureQueriesContext(connection) as queries:
                res = self.api.get(path)
            self.assertEqual(res.status_code, 200, f"{path} -> {res.status_code}")
            counts[path] = len(queries.captured_queries)
        return counts

    def test_query_count_does_not_grow_with_rows(self):
        self.add_rows(1)
        # Warm-up pass: the first request of a test also refreshes last_active_at.
        self.query_counts()
        with_one = self.query_counts()
        self.add_rows(5)
        with_six = self.query_counts()
        for path in LIST_PAGES:
            self.assertEqual(with_six[path], with_one[path], f"{path} runs extra queries per row")
