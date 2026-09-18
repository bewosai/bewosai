from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import User, Business, StaffMember
from parties.balances import party_balances
from parties.models import Party, PartyPayment
from parties.views import PartyPaymentListCreateView
from purchases.models import Purchase, PurchaseReturn
from sales.models import Sale, SaleReturn


def D(x):
    return Decimal(str(x))


class PartyBalanceTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)

    def party(self, opening=0, name="Ram"):
        return Party.objects.create(business=self.business, name=name, opening_balance=D(opening))

    def sale(self, party, total, paid=0, status="CONFIRMED", number="S1"):
        return Sale.objects.create(
            business=self.business, customer=party, invoice_number=number, sale_date=date(2026, 1, 1),
            subtotal=D(total), paid_amount=D(paid), status=status,
        )

    def purchase(self, party, total, paid=0, number="P1"):
        return Purchase.objects.create(
            business=self.business, supplier=party, bill_number=number, purchase_date=date(2026, 1, 1),
            subtotal=D(total), paid_amount=D(paid),
        )

    def pay(self, party, kind, amount):
        payment = PartyPayment.objects.create(
            party=party, payment_type=kind, amount=D(amount), date=date(2026, 1, 2), created_by=self.owner,
        )
        PartyPaymentListCreateView._reconcile_payment(payment)
        return payment

    def test_opening_balance_alone(self):
        self.assertEqual(self.party(500).balance, D(500))
        self.assertEqual(self.party(-300, "Sita").balance, D(-300))

    def test_payment_pays_down_an_opening_balance_with_no_invoices(self):
        p = self.party(1000)
        self.pay(p, "IN", 400)
        self.assertEqual(p.balance, D(600))
        self.pay(p, "IN", 600)
        self.assertEqual(p.balance, D(0))

    def test_payment_out_pays_down_an_opening_payable(self):
        p = self.party(-1000)
        self.pay(p, "OUT", 250)
        self.assertEqual(p.balance, D(-750))

    def test_payment_beyond_the_invoice_becomes_an_advance(self):
        p = self.party(0)
        self.sale(p, 500)
        self.pay(p, "IN", 800)          # 500 settles the invoice, 300 is left over
        self.assertEqual(p.balance, D(-300))   # we now owe them 300

    def test_payment_splits_between_invoice_and_opening_balance(self):
        p = self.party(1000)
        self.sale(p, 500)
        self.pay(p, "IN", 800)          # 500 to the invoice, 300 off the opening balance
        self.assertEqual(p.balance, D(700))

    def test_invoice_dues_and_purchase_dues_net_for_a_both_party(self):
        p = self.party(0)
        self.sale(p, 1000, paid=200)
        self.purchase(p, 300)
        self.assertEqual(p.balance, D(500))    # 800 owed to us - 300 we owe

    def test_returns_reduce_what_is_owed(self):
        p = self.party(0)
        s = self.sale(p, 1000)
        SaleReturn.objects.create(
            original_sale=s, business=self.business, return_date=date(2026, 1, 3), amount=D(300),
        )
        self.assertEqual(p.balance, D(700))
        supplier = self.party(0, "Supplier")
        bill = self.purchase(supplier, 800)
        PurchaseReturn.objects.create(
            original_purchase=bill, business=self.business, return_date=date(2026, 1, 3), amount=D(200),
        )
        self.assertEqual(supplier.balance, D(-600))

    def test_draft_and_cancelled_sales_do_not_count(self):
        p = self.party(0)
        self.sale(p, 400, status="DRAFT", number="S-D")
        self.sale(p, 400, status="CANCELLED", number="S-C")
        self.assertEqual(p.balance, D(0))

    def test_deleted_payment_no_longer_counts(self):
        p = self.party(1000)
        payment = self.pay(p, "IN", 400)
        payment.is_deleted = True
        payment.save()
        self.assertEqual(p.balance, D(1000))

    def test_totals_match_the_sum_of_party_balances_and_ledger(self):
        a = self.party(1000, "A")
        b = self.party(-200, "B")
        self.sale(a, 500, number="S-A")
        self.pay(a, "IN", 800)
        balances = party_balances(self.business.id)
        self.assertEqual(balances[a.id], a.balance)
        self.assertEqual(balances[b.id], b.balance)

        client = APIClient()
        client.force_authenticate(self.owner)
        res = client.get(f"/api/parties/{a.id}/ledger/", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(D(res.data["closing_balance"]), a.balance)

    def test_dashboard_totals_equal_what_the_parties_screen_sums_to(self):
        a = self.party(1000, "A")             # 1000 owed to us
        self.party(-200, "B")                 # 200 we owe
        self.sale(a, 500, number="S-A")
        self.pay(a, "IN", 800)                # 500 to the invoice, 300 off opening -> A owes 700
        client = APIClient()
        client.force_authenticate(self.owner)
        res = client.get("/api/reports/dashboard/", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(D(res.data["total_receivable"]), D(700))
        self.assertEqual(D(res.data["total_payable"]), D(200))

    def test_dashboard_still_loads_if_the_balance_calculation_fails(self):
        from unittest import mock

        a = self.party(0, "A")
        self.sale(a, 500, number="S-A")
        client = APIClient()
        client.force_authenticate(self.owner)
        with mock.patch("parties.balances.party_balances", side_effect=RuntimeError("boom")):
            with self.assertLogs("reports.views", level="ERROR"):
                res = client.get("/api/reports/dashboard/", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(D(res.data["total_receivable"]), D(500))   # plain invoice dues
