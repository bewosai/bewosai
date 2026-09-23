"""
A sale return first reduces what the customer still owes (parties.balances
already does that independently — see SaleReturn's docstring); only the part
beyond what was due is real money paid back, and that's what refunded_amount/
refund_method/bank_account track, feeding the cash reports and — for a bank
refund — a real BankTransaction.
"""
from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from banking.models import BankAccount, BankTransaction
from inventory.models import Product
from parties.models import Party
from sales.models import Sale, SaleReturn


def D(x):
    return Decimal(str(x))


class SaleReturnRefundTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)
        self.customer = Party.objects.create(business=self.business, name="Ram")
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=D(100), purchase_price=D(60), stock_quantity=D(50),
        )

    def make_sale(self, total, paid):
        return Sale.objects.create(
            business=self.business, customer=self.customer, invoice_number=f"INV-{total}-{paid}",
            sale_date=date(2026, 9, 22), subtotal=D(total), total=D(total), paid_amount=D(paid),
            due_amount=D(total) - D(paid), status="CONFIRMED",
        )

    def return_via_api(self, sale, amount, refund_method="CASH", bank_account=None):
        payload = {
            "original_sale": sale.id, "return_date": "2026-09-22", "reason": "Damaged",
            "amount": str(amount), "refund_method": refund_method, "items": [],
        }
        if bank_account:
            payload["bank_account"] = bank_account.id
        return self.api.post("/api/sales/returns/", payload, format="json")

    def test_return_fully_absorbed_by_the_due_amount_refunds_nothing(self):
        sale = self.make_sale(total=1000, paid=200)   # due = 800
        res = self.return_via_api(sale, amount=300)   # well within the 800 due
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(Decimal(str(res.data["refunded_amount"])), D(0))
        self.assertFalse(BankTransaction.objects.exists())

    def test_return_beyond_the_due_amount_refunds_the_difference_in_cash(self):
        sale = self.make_sale(total=1000, paid=1000)  # due = 0, fully paid
        res = self.return_via_api(sale, amount=300, refund_method="CASH")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(Decimal(str(res.data["refunded_amount"])), D(300))
        self.assertFalse(BankTransaction.objects.exists())  # cash needs no bank row

    def test_return_partly_absorbed_refunds_only_the_leftover(self):
        sale = self.make_sale(total=1000, paid=800)   # due = 200
        res = self.return_via_api(sale, amount=500)   # 200 absorbed, 300 left over
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(Decimal(str(res.data["refunded_amount"])), D(300))

    def test_bank_refund_requires_an_account_and_creates_a_transaction(self):
        sale = self.make_sale(total=1000, paid=1000)
        missing = self.return_via_api(sale, amount=300, refund_method="BANK")
        self.assertEqual(missing.status_code, 400)

        account = BankAccount.objects.create(business=self.business, account_name="Main", account_type="BANK")
        res = self.return_via_api(sale, amount=300, refund_method="BANK", bank_account=account)
        self.assertEqual(res.status_code, 201, res.content)
        txn = BankTransaction.objects.get(reference=f"SALERETURN-{res.data['id']}")
        self.assertEqual(txn.transaction_type, "DEBIT")
        self.assertEqual(txn.amount, D(300))

    def test_original_sales_due_amount_is_untouched_by_a_return(self):
        # parties.balances already nets the return against the party's balance
        # independently — Sale.due_amount itself must NOT also be reduced, or
        # the return would be counted twice.
        sale = self.make_sale(total=1000, paid=200)
        due_before = sale.due_amount
        self.return_via_api(sale, amount=300)
        sale.refresh_from_db()
        self.assertEqual(sale.due_amount, due_before)

    def test_cash_reports_reflect_only_the_actual_refund(self):
        sale = self.make_sale(total=1000, paid=1000)  # a cash sale: +1000 cash in
        self.return_via_api(sale, amount=300, refund_method="CASH")

        dash = self.api.get("/api/reports/dashboard/")
        # +1000 from the original cash sale, -300 refunded back out.
        self.assertEqual(Decimal(str(dash.data["cash_balance"])), D(700))

        flow = self.api.get("/api/reports/cash-flow/", {"date_from": "2026-09-22", "date_to": "2026-09-22"})
        self.assertEqual(Decimal(str(flow.data["cash_out"]["sales_returns"])), D(300))

        hand = self.api.get("/api/reports/cash-in-hand/", {"date_from": "2026-09-22", "date_to": "2026-09-22"})
        refs = {e["ref"]: e for e in hand.data["entries"]}
        self.assertEqual(refs[f"SR-{SaleReturn.objects.get().id}"]["credit"], 300.0)

    def test_a_due_only_return_does_not_appear_in_any_cash_report(self):
        sale = self.make_sale(total=1000, paid=200)  # a cash sale: +200 cash in
        cash_before = self.api.get("/api/reports/dashboard/").data["cash_balance"]
        self.return_via_api(sale, amount=300)  # fully absorbed, no money moved

        dash = self.api.get("/api/reports/dashboard/")
        # Unchanged by the return — only the original sale's own cash counts.
        self.assertEqual(dash.data["cash_balance"], cash_before)
        hand = self.api.get("/api/reports/cash-in-hand/", {"date_from": "2026-09-22", "date_to": "2026-09-22"})
        self.assertEqual([e for e in hand.data["entries"] if e["type"] in ("SALE_RETURN", "PURCHASE_RETURN")], [])
