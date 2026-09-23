"""
A staff member signs in with the link the owner shared and gets exactly what the
owner allowed: the app is told what they may use (so it can hide the rest), the
server refuses everything else — including the corners that used to leak (the
recycle bin, dashboard totals, colleagues' login history, coupons) — and whatever
they create lands in the owner's business.
"""
from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from bewosai.permissions import PERMISSION_ACTIONS, PERMISSION_MODULES, permission_matrix, staff_can
from expenses.models import Expense
from inventory.models import Product
from sales.models import Sale

ALL = {"view": True, "create": True, "edit": True, "delete": True}
NONE = {"view": False, "create": False, "edit": False, "delete": False}
_METHOD = {"view": "GET", "create": "POST", "edit": "PATCH", "delete": "DELETE"}


class StaffAccessTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.header = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        self.owner_api = APIClient(**self.header)
        self.owner_api.force_authenticate(self.owner)
        self.staff_url = f"/api/auth/businesses/{self.business.id}/staff/"
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=Decimal("100"), purchase_price=Decimal("60"),
            stock_quantity=Decimal("50"),
        )

    # ── helpers ──────────────────────────────────────────────────────────
    def invite(self, name="Sita", role="CASHIER", permissions=None):
        res = self.owner_api.post(
            self.staff_url, {"name": name, "role": role, "permissions": permissions or {}}, format="json",
        )
        self.assertEqual(res.status_code, 201, res.content)
        return res.data

    def sign_in(self, token):
        """Log in with the shared link. Returns (client, login response data)."""
        res = APIClient().post("/api/auth/staff-login/", {"token": token}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        client = APIClient(**self.header)
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        return client, res.data

    def staff(self, permissions, role="CASHIER"):
        member = self.invite(role=role, permissions=permissions)
        client, login = self.sign_in(member["login_token"])
        return client, login, member

    # ── the client is told what the staff member may do ──────────────────
    def test_login_response_carries_the_role_and_what_is_allowed(self):
        perms = {"sales": {**ALL, "delete": False}, "purchases": NONE}
        _, login, _ = self.staff(perms, role="CASHIER")
        biz = login["businesses"][0]
        self.assertEqual(biz["my_role"], "CASHIER")
        self.assertEqual(biz["my_permissions"]["sales"], {"view": True, "create": True, "edit": True, "delete": False})
        self.assertEqual(biz["my_permissions"]["purchases"], NONE)
        # never configured -> allowed, like the server treats it; "staff" is never implied
        self.assertEqual(biz["my_permissions"]["expenses"], ALL)
        self.assertEqual(biz["my_permissions"]["staff"], NONE)

    def test_the_owner_is_told_they_can_do_everything(self):
        res = self.owner_api.get("/api/auth/businesses/")
        self.assertEqual(res.status_code, 200, res.content)
        biz = (res.data["results"] if isinstance(res.data, dict) else res.data)[0]
        self.assertEqual(biz["my_role"], "OWNER")
        self.assertTrue(all(v for m in biz["my_permissions"].values() for v in m.values()))

    def test_the_table_the_clients_get_matches_what_the_server_enforces(self):
        configs = [
            {}, {"sales": NONE}, {"sales": {"view": True}}, {"expenses": {**ALL, "delete": False}},
            {"staff": ALL}, {"reports": {"view": False}, "inventory": {"create": False}},
        ]
        for perms in configs:
            member = self.invite(name=f"S{len(str(perms))}{abs(hash(str(perms))) % 999}", permissions=perms)
            user = User.objects.get(pk=member["user"])
            matrix = permission_matrix(user, self.business)
            for module in PERMISSION_MODULES:
                for action in PERMISSION_ACTIONS:
                    self.assertEqual(
                        matrix[module][action], staff_can(user, self.business, module, _METHOD[action]),
                        f"{perms} -> {module}.{action}",
                    )
            StaffMember.objects.filter(pk=member["id"]).delete()

    # ── data lands in the owner's business ───────────────────────────────
    def test_what_staff_create_belongs_to_the_owners_business(self):
        client, _, member = self.staff({"sales": ALL})
        res = client.post("/api/sales/", {
            "invoice_number": "INV-9", "sale_date": "2026-09-21", "discount": "0", "tax_rate": "0",
            "paid_amount": "100", "payment_method": "CASH",
            "items": [{"product": self.product.id, "product_name": "Rice", "quantity": "1", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        sale = Sale.objects.get(invoice_number="INV-9")
        self.assertEqual(sale.business_id, self.business.id)        # the owner's business
        self.assertEqual(sale.created_by_id, member["user"])         # attributed to the staff member
        # the owner sees it straight away
        owner_list = self.owner_api.get("/api/sales/").json()
        rows = owner_list["results"] if isinstance(owner_list, dict) else owner_list
        self.assertIn("INV-9", [r["invoice_number"] for r in rows])
        # and the staff member owns nothing of their own
        self.assertFalse(Business.objects.filter(owner_id=member["user"]).exists())

    def test_staff_can_only_do_what_was_ticked(self):
        client, _, _ = self.staff({"sales": {**ALL, "delete": False}, "purchases": NONE, "expenses": {"view": True, "create": False}})
        self.assertEqual(client.get("/api/sales/").status_code, 200)
        self.assertEqual(client.get("/api/purchases/").status_code, 403)
        self.assertEqual(client.get("/api/expenses/").status_code, 200)
        self.assertEqual(client.post("/api/expenses/", {"amount": "5", "date": "2026-09-21"}, format="json").status_code, 403)

    # ── the corners that used to leak ────────────────────────────────────
    def deleted_records(self):
        sale = Sale.objects.create(business=self.business, invoice_number="D1", sale_date=date(2026, 9, 1), is_deleted=True)
        expense = Expense.objects.create(business=self.business, amount=Decimal("50"), date=date(2026, 9, 1), is_deleted=True)
        return sale, expense

    def test_recycle_bin_lists_only_what_the_staff_member_may_view(self):
        sale, expense = self.deleted_records()
        client, _, _ = self.staff({"sales": ALL, "expenses": NONE})
        rows = client.get("/api/purchases/recycle-bin/").json()
        self.assertEqual({r["type"] for r in rows}, {"sale"})
        owner_rows = self.owner_api.get("/api/purchases/recycle-bin/").json()
        self.assertEqual({r["type"] for r in owner_rows}, {"sale", "expense"})

    def test_recycle_bin_restore_and_permanent_delete_need_delete_permission_on_that_module(self):
        sale, expense = self.deleted_records()
        client, _, _ = self.staff({"sales": {**ALL, "delete": False}, "expenses": NONE})
        # no delete on sales, nothing on expenses: both refused, nothing changed
        self.assertEqual(client.post(f"/api/purchases/recycle-bin/restore/sale/{sale.id}/").status_code, 403)
        self.assertEqual(client.post(f"/api/purchases/recycle-bin/restore/expense/{expense.id}/").status_code, 403)
        self.assertEqual(client.delete(f"/api/purchases/recycle-bin/delete/sale/{sale.id}/").status_code, 403)
        self.assertEqual(client.delete(f"/api/purchases/recycle-bin/delete/expense/{expense.id}/").status_code, 403)
        self.assertTrue(Sale.objects.filter(pk=sale.pk, is_deleted=True).exists())
        self.assertTrue(Expense.objects.filter(pk=expense.pk, is_deleted=True).exists())
        # the owner still can
        self.assertEqual(self.owner_api.post(f"/api/purchases/recycle-bin/restore/expense/{expense.id}/").status_code, 200)

    def test_delete_permission_on_the_module_is_enough_to_restore(self):
        sale, _ = self.deleted_records()
        client, _, _ = self.staff({"sales": ALL})
        self.assertEqual(client.post(f"/api/purchases/recycle-bin/restore/sale/{sale.id}/").status_code, 200)

    def test_dashboard_hides_figures_from_modules_the_staff_member_may_not_view(self):
        Sale.objects.create(
            business=self.business, invoice_number="T1", sale_date=date.today(), status="CONFIRMED",
            subtotal=Decimal("500"), total=Decimal("500"),
        )
        client, _, _ = self.staff({"sales": ALL, "reports": NONE, "expenses": NONE})
        data = client.get("/api/reports/dashboard/").json()
        self.assertEqual(data["sales_today"], 500)           # they may see sales
        self.assertEqual(data["profit_month"], 0)             # not the profit or cash
        self.assertEqual(data["cash_balance"], 0)
        self.assertEqual(data["expenses_month"], 0)
        self.assertEqual(sorted(data["restricted"]), ["expenses", "reports"])
        owner = self.owner_api.get("/api/reports/dashboard/").json()
        self.assertEqual(owner["restricted"], [])
        self.assertEqual(owner["sales_today"], 500)

    def test_colleagues_login_history_needs_the_staff_module(self):
        client, _, _ = self.staff({"sales": ALL})
        self.assertEqual(client.get("/api/staff/activity/").status_code, 403)
        self.assertEqual(self.owner_api.get("/api/staff/activity/").status_code, 200)

    def test_staff_cannot_apply_coupons_or_activate_licenses_but_the_owner_can_try(self):
        client, _, _ = self.staff({"sales": ALL})
        self.assertEqual(client.post("/api/billing/apply-coupon/", {"code": "X"}, format="json").status_code, 403)
        self.assertEqual(client.post("/api/auth/licenses/activate/", {"code": "ABCDE"}, format="json").status_code, 403)
        # the owner gets past the ownership check (this code just doesn't exist -> a normal 400)
        self.assertEqual(self.owner_api.post("/api/billing/apply-coupon/", {"code": "X"}, format="json").status_code, 400)

    def test_staff_cannot_edit_or_delete_the_business_itself(self):
        client, _, _ = self.staff({"sales": ALL})
        self.assertEqual(client.patch(f"/api/auth/businesses/{self.business.id}/", {"name": "Hacked"}, format="json").status_code, 404)
        self.assertEqual(client.delete(f"/api/auth/businesses/{self.business.id}/").status_code, 404)
        self.business.refresh_from_db()
        self.assertEqual(self.business.name, "Shop")
