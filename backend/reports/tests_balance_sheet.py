"""
Balance sheet (reports/balance_sheet.py): one small business month, checked
figure by figure, for today and for a date in the past — and it must agree
with the reports and balances the rest of the app already shows.
"""
from datetime import date, timedelta
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from banking.models import BankAccount
from inventory.models import Product
from parties.balances import party_balances
from parties.models import Party
from reports.balance_sheet import party_balances_as_of

D = lambda x: Decimal(str(x))  # noqa: E731


class BalanceSheetTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop", fiscal_year_start="01-01")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)

        self.today = timezone.localdate()
        self.d1 = self.today - timedelta(days=10)     # the "past" balance sheet date
        self.d2 = self.today - timedelta(days=3)      # after it

        self.bank = BankAccount.objects.create(
            business=self.business, account_name="NIC", account_type="BANK", opening_balance=D(5000),
        )
        self.ram = Party.objects.create(business=self.business, name="Ram", opening_balance=D(200))
        self.supplier = Party.objects.create(business=self.business, name="Hari Traders", party_type="SUPPLIER")
        self.rice = Product.objects.create(
            business=self.business, name="Rice", sale_price=D(100), purchase_price=D(60), stock_quantity=D(20),
        )
        Product.objects.filter(pk=self.rice.pk).update(created_at=timezone.now() - timedelta(days=30))

        # Day d1: bought 10 rice on credit (600), sold 5 to Ram for 500, paid 300 cash.
        self.post("/api/purchases/", {
            "supplier": self.supplier.id, "bill_number": "PUR-1", "purchase_date": self.d1.isoformat(),
            "payment_method": "CASH", "paid_amount": "0", "status": "CONFIRMED",
            "items": [{"product": self.rice.id, "product_name": "Rice", "quantity": "10", "unit_price": "60"}],
        })
        self.post("/api/sales/", {
            "customer": self.ram.id, "invoice_number": "INV-1", "sale_date": self.d1.isoformat(),
            "payment_method": "CASH", "paid_amount": "300", "status": "CONFIRMED",
            "items": [{"product": self.rice.id, "product_name": "Rice", "quantity": "5", "unit_price": "100"}],
        })
        # Day d2: sold 2 more by bank (200, paid), Ram paid 250 cash, rent 100 cash.
        self.post("/api/sales/", {
            "invoice_number": "INV-2", "sale_date": self.d2.isoformat(), "payment_method": "BANK",
            "bank_account": self.bank.id, "paid_amount": "200", "status": "CONFIRMED",
            "items": [{"product": self.rice.id, "product_name": "Rice", "quantity": "2", "unit_price": "100"}],
        })
        self.post("/api/parties/payments/", {
            "party": self.ram.id, "payment_type": "IN", "amount": "250", "payment_method": "CASH",
            "date": self.d2.isoformat(),
        })
        self.post("/api/expenses/", {"amount": "100", "date": self.d2.isoformat(), "payment_method": "CASH",
                                     "description": "Rent"})

    def post(self, url, data):
        res = self.api.post(url, data, format="json")
        self.assertIn(res.status_code, (200, 201), f"{url}: {res.content}")
        return res

    def sheet(self, **params):
        res = self.api.get("/api/reports/balance-sheet/", params)
        self.assertEqual(res.status_code, 200, res.content)
        return res.data

    def test_today(self):
        s = self.sheet()
        a, l, e = s["assets"], s["liabilities"], s["equity"]
        self.assertEqual(a["cash_in_hand"], 300 + 250 - 100)       # 450
        self.assertEqual(a["bank_total"], 5000 + 200)
        self.assertEqual(a["receivables"], 200 + 500 - 300 - 250)  # Ram: 150
        self.assertEqual(a["stock"], (20 + 10 - 5 - 2) * 60)       # 23 rice at 60
        self.assertFalse(a["stock_is_estimate"])
        self.assertEqual(l["payables"], 600)
        self.assertEqual(a["total"], 450 + 5200 + 150 + 1380)
        self.assertEqual(s["liabilities_and_equity_total"], a["total"])
        # Profit this year: sales 700 − cost 7×60 − rent 100 = 180.
        self.assertEqual(e["period_profit"], 180)
        self.assertEqual(e["total"], a["total"] - l["total"])

    def test_a_past_date_counts_only_what_happened_by_then(self):
        s = self.sheet(as_of=self.d1.isoformat())
        a, l = s["assets"], s["liabilities"]
        self.assertEqual(a["cash_in_hand"], 300)
        self.assertEqual(a["bank_total"], 5000)
        self.assertEqual(a["receivables"], 200 + 500 - 300)       # 400, before Ram's 250
        self.assertEqual(a["stock"], (20 + 10 - 5) * 60)          # the 2 sold on d2 still here
        self.assertTrue(a["stock_is_estimate"])
        self.assertEqual(l["payables"], 600)
        self.assertEqual(s["equity"]["period_profit"], 500 - 5 * 60)
        self.assertEqual(s["liabilities_and_equity_total"], a["total"])

    def test_start_date_sets_the_profit_period(self):
        s = self.sheet(date_from=self.d2.isoformat())
        self.assertEqual(s["date_from"], self.d2.isoformat())
        self.assertEqual(s["equity"]["period_profit"], 200 - 2 * 60 - 100)
        # The owner's total share doesn't depend on where the period starts.
        self.assertEqual(s["equity"]["total"], self.sheet()["equity"]["total"])

    def test_agrees_with_the_party_balances_and_reports(self):
        self.assertEqual(
            {k: v for k, v in party_balances_as_of(self.business.id, self.today).items()},
            party_balances(self.business.id),
        )
        s = self.sheet()
        cash = self.api.get("/api/reports/cash-in-hand/", {"date_from": "2000-01-01"}).data["closing_balance"]
        self.assertEqual(s["assets"]["cash_in_hand"], cash)
        self.bank.refresh_from_db()
        self.assertEqual(Decimal(str(s["assets"]["bank_total"])), self.bank.balance)
        profit = self.api.get("/api/reports/profit/", {"date_from": s["date_from"],
                                                         "date_to": s["as_of"]}).data["net_profit"]
        self.assertEqual(s["equity"]["period_profit"], profit)

    def test_bad_dates_are_refused_plainly(self):
        for params in ({"as_of": "2026-02-30"}, {"as_of": "abc"}, {"date_from": "nope"},
                       {"as_of": (self.today + timedelta(days=1)).isoformat()},
                       {"as_of": self.d1.isoformat(), "date_from": self.d2.isoformat()}):
            res = self.api.get("/api/reports/balance-sheet/", params)
            self.assertEqual(res.status_code, 400, params)

    def test_another_business_cannot_see_it(self):
        other = User.objects.create_user(email="other@example.com", name="Other")
        api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        api.force_authenticate(other)
        self.assertIn(api.get("/api/reports/balance-sheet/").status_code, (403, 404))
