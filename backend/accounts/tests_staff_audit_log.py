"""
The owner-facing "who changed what, and when" log (accounts.StaffActivity,
populated by superadmin.signals, served by StaffAuditLogView) — creation,
edits with before/after values, deletion, permission gating, and filtering.
"""
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffActivity, StaffMember, User
from expenses.models import Expense
from inventory.models import Product
from parties.models import Party
from sales.models import Sale


class StaffAuditLogTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.owner_api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.owner_api.force_authenticate(self.owner)
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=Decimal("100"), purchase_price=Decimal("60"),
            stock_quantity=Decimal("50"),
        )

    def log(self):
        res = self.owner_api.get("/api/staff/audit-log/")
        self.assertEqual(res.status_code, 200, res.content)
        return res.data["results"]

    def test_creating_a_product_is_logged_with_the_owner_attributed(self):
        res = self.owner_api.post("/api/inventory/products/", {
            "name": "Sugar", "sale_price": "80", "purchase_price": "60", "stock_quantity": "10",
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        entries = [e for e in self.log() if e["object_type"] == "Product" and "Sugar" in e["object_repr"]]
        self.assertEqual(len(entries), 1)
        entry = entries[0]
        self.assertEqual(entry["action"], "CREATE")
        self.assertEqual(entry["module"], "inventory")
        self.assertIn("Created", entry["description"])

    def test_editing_a_product_logs_only_what_changed_with_before_and_after(self):
        res = self.owner_api.patch(f"/api/inventory/products/{self.product.id}/", {
            "sale_price": "120",  # changed
            "name": "Rice",       # unchanged
        }, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        entries = [e for e in self.log() if e["object_type"] == "Product" and e["action"] == "UPDATE"]
        self.assertEqual(len(entries), 1)
        entry = entries[0]
        self.assertEqual(entry["old_data"], {"sale_price": "100.00"})
        self.assertEqual(entry["new_data"], {"sale_price": "120.00"})
        self.assertIn("Sale price: 100.00 → 120.00", entry["description"])

    def test_an_edit_that_touches_no_watched_field_is_not_logged(self):
        # Same values sent back — a real no-op save.
        res = self.owner_api.patch(f"/api/inventory/products/{self.product.id}/", {
            "name": "Rice", "sale_price": "100", "purchase_price": "60", "stock_quantity": "50",
        }, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual([e for e in self.log() if e["action"] == "UPDATE"], [])

    def test_choice_fields_show_their_label_not_their_stored_code(self):
        customer = Party.objects.create(business=self.business, name="Ram")
        sale = Sale.objects.create(
            business=self.business, customer=customer, invoice_number="INV-1",
            sale_date="2026-09-22", subtotal=Decimal("100"), total=Decimal("100"), payment_method="CASH",
        )
        res = self.owner_api.patch(f"/api/sales/{sale.id}/", {"payment_method": "BANK"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        entries = [e for e in self.log() if e["object_type"] == "Sale" and e["action"] == "UPDATE"]
        self.assertEqual(len(entries), 1)
        self.assertIn("Bank", str(entries[0]["new_data"]["payment_method"]))

    def test_deleting_an_expense_is_logged(self):
        expense = Expense.objects.create(business=self.business, amount=Decimal("500"), date="2026-09-22")
        res = self.owner_api.delete(f"/api/expenses/{expense.id}/")
        self.assertEqual(res.status_code, 204, res.content)
        entries = [e for e in self.log() if e["object_type"] == "Expense"]
        self.assertTrue(any(e["action"] == "DELETE" for e in entries))

    def test_a_staff_members_action_is_attributed_to_them_not_the_owner(self):
        member = StaffMember.objects.create(
            user=User.objects.create_user(email="cashier@example.com", name="Cashier"),
            business=self.business, role=StaffMember.ROLE_CASHIER,
            permissions={"inventory": {"view": True, "create": True, "edit": True, "delete": True}},
            login_token=StaffMember.new_login_token(),
        )
        login = APIClient().post("/api/auth/staff-login/", {"token": member.login_token}, format="json")
        self.assertEqual(login.status_code, 200, login.content)
        staff_api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        staff_api.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        res = staff_api.patch(f"/api/inventory/products/{self.product.id}/", {"stock_quantity": "5"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)

        entries = [e for e in self.log() if e["action"] == "UPDATE" and e["object_type"] == "Product"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["user"], member.user_id)
        self.assertEqual(entries[0]["user_name"], "Cashier")

    def test_filters_by_staff_module_action_and_date(self):
        self.owner_api.post("/api/inventory/products/", {
            "name": "Oil", "sale_price": "50", "purchase_price": "40", "stock_quantity": "5",
        }, format="json")
        self.owner_api.post("/api/expenses/", {"amount": "200", "date": "2026-09-22"}, format="json")

        by_module = self.owner_api.get("/api/staff/audit-log/", {"module": "expenses"}).data["results"]
        self.assertTrue(all(e["module"] == "expenses" for e in by_module))
        self.assertTrue(any(e["object_type"] == "Expense" for e in by_module))

        by_action = self.owner_api.get("/api/staff/audit-log/", {"action": "create"}).data["results"]
        self.assertTrue(all(e["action"] == "CREATE" for e in by_action))

        by_staff = self.owner_api.get("/api/staff/audit-log/", {"staff": self.owner.id}).data["results"]
        self.assertTrue(all(e["user"] == self.owner.id for e in by_staff))

        future = self.owner_api.get("/api/staff/audit-log/", {"date_from": "2099-01-01"}).data["results"]
        self.assertEqual(future, [])

    def test_a_staff_member_without_the_staff_module_cannot_see_the_log(self):
        member = StaffMember.objects.create(
            user=User.objects.create_user(email="viewer@example.com", name="Viewer"),
            business=self.business, role=StaffMember.ROLE_VIEWER,
            permissions={"staff": {"view": False, "create": False, "edit": False, "delete": False}},
            login_token=StaffMember.new_login_token(),
        )
        login = APIClient().post("/api/auth/staff-login/", {"token": member.login_token}, format="json")
        staff_api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        staff_api.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        self.assertEqual(staff_api.get("/api/staff/audit-log/").status_code, 403)

    def test_a_staff_member_with_the_staff_module_can_see_the_log(self):
        member = StaffMember.objects.create(
            user=User.objects.create_user(email="mgr@example.com", name="Mgr"),
            business=self.business, role=StaffMember.ROLE_MANAGER,
            permissions={"staff": {"view": True, "create": False, "edit": False, "delete": False}},
            login_token=StaffMember.new_login_token(),
        )
        login = APIClient().post("/api/auth/staff-login/", {"token": member.login_token}, format="json")
        staff_api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        staff_api.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        self.assertEqual(staff_api.get("/api/staff/audit-log/").status_code, 200)

    def test_activity_in_another_business_never_appears(self):
        other_owner = User.objects.create_user(email="other@example.com", name="Other")
        other_biz = Business.objects.create(owner=other_owner, name="Other Shop")
        StaffMember.objects.create(user=other_owner, business=other_biz, role=StaffMember.ROLE_OWNER)
        other_api = APIClient(HTTP_X_BUSINESS_ID=str(other_biz.id))
        other_api.force_authenticate(other_owner)
        other_api.post("/api/expenses/", {"amount": "999", "date": "2026-09-22"}, format="json")

        mine = self.log()
        self.assertFalse(any(e["object_repr"] == "Expense Rs.999" for e in mine))
        self.assertEqual(StaffActivity.objects.filter(business=self.business).count(), len(self.log()))
