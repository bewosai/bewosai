"""
One real HTTP call per endpoint SuperAdminPage.jsx actually uses (see its api
calls: stats, businesses, users, login-activity, activity, announcements,
features, licenses, coupons, referrals, tickets) against a database with real
data in every shape today's changes touched, checking only "does this crash
or 500" — the exact question "superadmin page error free" is asking.
"""
from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, LoginActivity, StaffMember, User
from billing.services import _extend_and_grant
from expenses.models import Expense
from inventory.models import Product
from parties.models import Party
from purchases.models import Purchase
from sales.models import Sale


class SuperAdminPageEndpointsTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_user(email="sa@example.com", name="SA", is_platform_admin=True)
        self.api = APIClient()
        self.api.force_authenticate(self.admin)

        owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        cashier = StaffMember.objects.create(
            user=User.objects.create_user(email="cashier@example.com", name="Cashier"),
            business=self.business, role=StaffMember.ROLE_CASHIER,
            permissions={"sales": {"view": True, "create": True, "edit": False, "delete": False}},
        )
        LoginActivity.objects.create(user=owner, user_agent="Mozilla/5.0 Chrome", platform="web")
        LoginActivity.objects.create(user=cashier.user, user_agent="Dart/3 (dart:io)", platform="app")
        LoginActivity.objects.create(user=owner, user_agent="okhttp/4.12")  # a pre-platform-field row

        customer = Party.objects.create(business=self.business, name="Ram")
        Sale.objects.create(
            business=self.business, customer=customer, invoice_number="INV-1", sale_date=date(2026, 9, 22),
            subtotal=Decimal("500"), total=Decimal("500"), paid_amount=Decimal("500"), status="CONFIRMED",
        )
        Purchase.objects.create(
            business=self.business, bill_number="P-1", purchase_date=date(2026, 9, 22),
            subtotal=Decimal("200"), total=Decimal("200"), status="CONFIRMED",
        )
        Expense.objects.create(business=self.business, amount=Decimal("50"), date=date(2026, 9, 22))
        Product.objects.create(business=self.business, name="Rice", sale_price=Decimal("10"), purchase_price=Decimal("6"))

        # A referral-rewarded (no admin creator) coupon, exercising the null
        # created_by path (see earlier probe).
        _extend_and_grant(business=self.business, plan="PREMIUM", coupon_user=owner)

    def get(self, path, params=None):
        res = self.api.get(path, params or {})
        self.assertLess(res.status_code, 500, f"{path} -> {res.status_code}: {res.content[:300]}")
        return res

    def test_overview_stats(self):
        self.get("/api/superadmin/stats/")

    def test_businesses_list_and_data(self):
        # BusinessEditDeleteView is PATCH/DELETE only — the page never GETs a
        # single business by id, it reads rows straight from the list below.
        self.get("/api/superadmin/businesses/")
        self.get(f"/api/superadmin/businesses/{self.business.id}/data/")
        self.get(f"/api/superadmin/businesses/{self.business.id}/features/")

    def test_users_list_ordering_and_search(self):
        for ordering in ["active", "login", "logins", "created", "name", None]:
            params = {"ordering": ordering} if ordering else {}
            self.get("/api/superadmin/users/", params)
        self.get("/api/superadmin/users/", {"search": "cashier"})

    def test_login_activity(self):
        self.get("/api/superadmin/login-activity/")

    def test_activity_feed(self):
        self.get("/api/superadmin/activity/")

    def test_announcements_features_tickets(self):
        self.get("/api/superadmin/announcements/")
        self.get("/api/superadmin/features/")
        self.get("/api/superadmin/tickets/")

    def test_licenses(self):
        self.get("/api/superadmin/licenses/")
        self.get("/api/superadmin/licenses/years/")
        self.get("/api/superadmin/licenses/audit-log/")

    def test_coupons_and_referrals(self):
        self.get("/api/superadmin/coupons/")
        self.get("/api/superadmin/referrals/")
        self.get("/api/superadmin/referrals/stats/")

    def test_staff_audit_log_via_a_business_owner_not_superadmin(self):
        # Not a SuperAdminPage call, but shares code (StaffActivity/signals) —
        # exercised here too since it's new today.
        owner_api = APIClient()
        owner_api.force_authenticate(User.objects.get(email="owner@example.com"))
        res = owner_api.get(
            "/api/staff/audit-log/", {}, HTTP_X_BUSINESS_ID=str(self.business.id),
        )
        self.assertLess(res.status_code, 500, res.content[:300])
