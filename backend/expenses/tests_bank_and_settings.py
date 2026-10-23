"""
Every box on the forms reaches the backend:
- an expense paid by bank/wallet takes its money out of the chosen account;
- invoice settings are saved on the business (not one browser), and the
  invoice prefix really numbers new invoices.
"""
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from banking.models import BankAccount


class ExpenseBankTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        self.bank = BankAccount.objects.create(
            business=self.business, account_name="eSewa", account_type="ESEWA", opening_balance=Decimal("1000"),
        )
        self.today = timezone.localdate().isoformat()

    def balance(self):
        self.bank.refresh_from_db()
        return self.bank.balance

    def spend(self, **extra):
        res = self.api.post("/api/expenses/", {
            "amount": "300", "date": self.today, "description": "Internet", **extra,
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data

    def test_bank_expense_reduces_the_account_and_delete_restore_follow(self):
        exp = self.spend(payment_method="ESEWA", bank_account=self.bank.id)
        self.assertEqual(exp["bank_account_name"], "eSewa")
        self.assertEqual(self.balance(), Decimal("700"))
        self.assertEqual(self.api.delete(f"/api/expenses/{exp['id']}/").status_code, 204)
        self.assertEqual(self.balance(), Decimal("1000"))
        self.api.post(f"/api/purchases/recycle-bin/restore/expense/{exp['id']}/")
        self.assertEqual(self.balance(), Decimal("700"))

    def test_editing_the_amount_or_switching_to_cash_updates_the_account(self):
        exp = self.spend(payment_method="BANK", bank_account=self.bank.id)
        self.api.patch(f"/api/expenses/{exp['id']}/", {"amount": "100"}, format="json")
        self.assertEqual(self.balance(), Decimal("900"))
        res = self.api.patch(f"/api/expenses/{exp['id']}/", {"payment_method": "CASH"}, format="json")
        self.assertIsNone(res.data["bank_account"])
        self.assertEqual(self.balance(), Decimal("1000"))

    def test_receipt_photo_can_be_removed(self):
        from expenses.models import Expense

        exp = self.spend(payment_method="CASH")
        Expense.objects.filter(pk=exp["id"]).update(receipt_image="expenses/receipts/r.jpg")
        res = self.api.patch(f"/api/expenses/{exp['id']}/", {"receipt_image": None}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertFalse(Expense.objects.get(pk=exp["id"]).receipt_image)

    def test_cash_expense_touches_no_account(self):
        self.spend(payment_method="CASH", bank_account=self.bank.id)
        self.assertEqual(self.balance(), Decimal("1000"))

    def test_another_business_account_is_refused(self):
        other_owner = User.objects.create_user(email="x@example.com", name="X")
        other = Business.objects.create(owner=other_owner, name="Other")
        theirs = BankAccount.objects.create(business=other, account_name="Theirs", account_type="BANK")
        res = self.api.post("/api/expenses/", {"amount": "5", "date": self.today, "payment_method": "BANK",
                                               "bank_account": theirs.id}, format="json")
        self.assertEqual(res.status_code, 400)


class InvoiceSettingsTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)

    def save(self, **settings):
        return self.api.patch(f"/api/auth/businesses/{self.business.id}/", {"invoice_settings": settings},
                              format="json")

    def test_settings_are_saved_on_the_business(self):
        res = self.save(header_color="#2563eb", footer_text="Dhanyabad!", terms_text="7 days", warranty_text="")
        self.assertEqual(res.status_code, 200, res.content)
        self.business.refresh_from_db()
        self.assertEqual(self.business.invoice_settings["footer_text"], "Dhanyabad!")
        self.save(terms_text="15 days")                     # a partial save keeps the rest
        self.business.refresh_from_db()
        self.assertEqual(self.business.invoice_settings["footer_text"], "Dhanyabad!")
        self.assertEqual(self.business.invoice_settings["terms_text"], "15 days")

    def test_prefix_numbers_new_invoices(self):
        self.save(invoice_prefix="BWS-")
        res = self.api.get("/api/sales/next-number/")
        self.assertEqual(res.data["next_number"], "BWS-0001")
        res = self.api.post("/api/sales/", {
            "sale_date": timezone.localdate().isoformat(), "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "1", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(res.data["invoice_number"], "BWS-0001")
        self.assertEqual(self.api.get("/api/sales/next-number/").data["next_number"], "BWS-0002")

    def test_bad_values_are_refused(self):
        for bad in ({"header_color": "red"}, {"invoice_prefix": "IN V"}, {"nope": "x"}, {"footer_text": "x" * 301}):
            self.assertEqual(self.save(**bad).status_code, 400, bad)
