"""
A sale or purchase paid by bank/wallet keeps a mirrored BankTransaction. Only a
confirmed, not-deleted document has really moved that money — the same rule the
cash reports use — so deleting or cancelling it must take the bank entry away,
and restoring it from the Recycle Bin must put it back.
"""
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from banking.models import BankAccount, BankTransaction


class BankMirrorFollowsTheDocumentTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        self.bank = BankAccount.objects.create(
            business=self.business, account_name="NIC", account_type="BANK", opening_balance=Decimal("5000"),
        )
        self.today = timezone.localdate().isoformat()

    def sell(self):
        res = self.api.post("/api/sales/", {
            "invoice_number": "INV-1", "sale_date": self.today, "payment_method": "BANK",
            "bank_account": self.bank.id, "paid_amount": "1000", "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "10", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    def buy(self):
        res = self.api.post("/api/purchases/", {
            "bill_number": "PUR-1", "purchase_date": self.today, "payment_method": "BANK",
            "bank_account": self.bank.id, "paid_amount": "600", "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "10", "unit_price": "60"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    def bank_balance(self):
        self.bank.refresh_from_db()
        return self.bank.balance

    def test_deleting_a_bank_sale_takes_its_money_out_of_the_bank(self):
        sale_id = self.sell()
        self.assertEqual(self.bank_balance(), Decimal("6000"))
        self.assertEqual(self.api.delete(f"/api/sales/{sale_id}/").status_code, 204)
        self.assertEqual(self.bank_balance(), Decimal("5000"))
        self.assertFalse(BankTransaction.objects.filter(reference=f"SALE-{sale_id}").exists())

    def test_restoring_it_puts_the_money_back(self):
        sale_id = self.sell()
        self.api.delete(f"/api/sales/{sale_id}/")
        res = self.api.post(f"/api/purchases/recycle-bin/restore/sale/{sale_id}/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.bank_balance(), Decimal("6000"))

    def test_cancelling_a_bank_sale_takes_its_money_out_of_the_bank(self):
        sale_id = self.sell()
        res = self.api.patch(f"/api/sales/{sale_id}/", {"status": "CANCELLED"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.bank_balance(), Decimal("5000"))

    def test_repair_command_removes_entries_left_by_old_deletes(self):
        from io import StringIO
        from django.core.management import call_command
        from sales.models import Sale

        sale_id = self.sell()
        Sale.objects.filter(pk=sale_id).update(is_deleted=True)     # deleted the old way: entry left behind
        self.assertEqual(self.bank_balance(), Decimal("6000"))
        out = StringIO()
        call_command("resync_bank_mirrors", stdout=out)              # dry run changes nothing
        self.assertIn(f"SALE-{sale_id}", out.getvalue())
        self.assertEqual(self.bank_balance(), Decimal("6000"))
        call_command("resync_bank_mirrors", "--apply", stdout=StringIO())
        self.assertEqual(self.bank_balance(), Decimal("5000"))

    def test_deleting_and_restoring_a_bank_purchase(self):
        purchase_id = self.buy()
        self.assertEqual(self.bank_balance(), Decimal("4400"))
        self.assertEqual(self.api.delete(f"/api/purchases/{purchase_id}/").status_code, 204)
        self.assertEqual(self.bank_balance(), Decimal("5000"))
        self.api.post(f"/api/purchases/recycle-bin/restore/purchase/{purchase_id}/")
        self.assertEqual(self.bank_balance(), Decimal("4400"))
