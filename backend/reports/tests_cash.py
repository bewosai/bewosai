"""
Every "how much actual cash is there" figure — the Dashboard's Cash Balance,
the Cash Flow report, and the Cash In Hand ledger — must agree with each
other for the same data: cash-method transactions in full, a SPLIT
transaction's cash portion only (never its bank portion), and never a
BANK-only transaction at all.
"""
from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from expenses.models import Expense
from parties.models import Party, PartyPayment
from purchases.models import Purchase
from sales.models import Sale


def D(x):
    return Decimal(str(x))


class CashFiguresAgreeTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)
        self.today = date(2026, 9, 22)

        # A plain cash sale: Rs 500 cash in.
        Sale.objects.create(
            business=self.business, invoice_number="S-CASH", sale_date=self.today, status="CONFIRMED",
            subtotal=D(500), total=D(500), paid_amount=D(500), payment_method="CASH",
        )
        # A bank-only sale: must never count as cash anywhere.
        Sale.objects.create(
            business=self.business, invoice_number="S-BANK", sale_date=self.today, status="CONFIRMED",
            subtotal=D(1000), total=D(1000), paid_amount=D(1000), payment_method="BANK",
        )
        # A split sale: Rs 200 of it is cash, Rs 800 went to the bank.
        Sale.objects.create(
            business=self.business, invoice_number="S-SPLIT", sale_date=self.today, status="CONFIRMED",
            subtotal=D(1000), total=D(1000), paid_amount=D(1000), payment_method="SPLIT", cash_amount=D(200),
        )
        # A cash purchase: Rs 300 cash out.
        Purchase.objects.create(
            business=self.business, bill_number="P-CASH", purchase_date=self.today, status="CONFIRMED",
            subtotal=D(300), total=D(300), paid_amount=D(300), payment_method="CASH",
        )
        # A split purchase: Rs 50 of it is cash out, Rs 150 from the bank.
        Purchase.objects.create(
            business=self.business, bill_number="P-SPLIT", purchase_date=self.today, status="CONFIRMED",
            subtotal=D(200), total=D(200), paid_amount=D(200), payment_method="SPLIT", cash_amount=D(50),
        )
        # A bank-only purchase: must never count as cash anywhere.
        Purchase.objects.create(
            business=self.business, bill_number="P-BANK", purchase_date=self.today, status="CONFIRMED",
            subtotal=D(900), total=D(900), paid_amount=D(900), payment_method="BANK",
        )
        Expense.objects.create(business=self.business, amount=D(40), date=self.today, payment_method="CASH")
        Expense.objects.create(business=self.business, amount=D(999), date=self.today, payment_method="BANK")

        # Expected net cash: (500 + 200) sales - (300 + 50) purchases - 40 expense = 310
        self.expected_cash_in = D(500) + D(200)
        self.expected_cash_out = D(300) + D(50) + D(40)
        self.expected_net = self.expected_cash_in - self.expected_cash_out

    def test_dashboard_cash_balance_counts_split_and_subtracts_cash_purchases(self):
        res = self.api.get("/api/reports/dashboard/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(Decimal(str(res.data["cash_balance"])), self.expected_net)

    def test_cash_flow_report_matches_the_dashboard(self):
        res = self.api.get("/api/reports/cash-flow/", {
            "date_from": self.today.isoformat(), "date_to": self.today.isoformat(),
        })
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(Decimal(str(res.data["cash_in"]["total"])), self.expected_cash_in)
        self.assertEqual(Decimal(str(res.data["cash_out"]["total"])), self.expected_cash_out)
        self.assertEqual(Decimal(str(res.data["net_cash_flow"])), self.expected_net)
        # The bank-only sale/purchase must be invisible here, specifically.
        self.assertEqual(Decimal(str(res.data["cash_in"]["sales_collection"])), self.expected_cash_in)
        self.assertEqual(Decimal(str(res.data["cash_out"]["purchases"])), D(300) + D(50))

    def test_cash_in_hand_ledger_matches_too(self):
        res = self.api.get("/api/reports/cash-in-hand/", {"date_from": self.today.isoformat(), "date_to": self.today.isoformat()})
        self.assertEqual(res.status_code, 200, res.content)
        refs = {e["ref"]: e for e in res.data["entries"]}
        self.assertNotIn("S-BANK", refs)
        self.assertNotIn("P-BANK", refs)
        self.assertEqual(refs["S-SPLIT"]["debit"], 200.0)
        self.assertEqual(refs["P-SPLIT"]["credit"], 50.0)
        # No history before "today" in this test, so opening balance is 0 and
        # closing balance is exactly this period's net.
        self.assertEqual(Decimal(str(res.data["closing_balance"])), self.expected_net)

    def test_a_party_payment_only_counts_toward_cash_when_its_method_is_cash(self):
        customer = Party.objects.create(business=self.business, name="Ram")
        PartyPayment.objects.create(party=customer, payment_type="IN", amount=D(60), payment_method="CASH", date=self.today)
        PartyPayment.objects.create(party=customer, payment_type="IN", amount=D(9999), payment_method="BANK", date=self.today)

        res = self.api.get("/api/reports/dashboard/")
        self.assertEqual(Decimal(str(res.data["cash_balance"])), self.expected_net + D(60))

        flow = self.api.get("/api/reports/cash-flow/", {
            "date_from": self.today.isoformat(), "date_to": self.today.isoformat(),
        })
        self.assertEqual(Decimal(str(flow.data["cash_in"]["party_payments"])), D(60))
