"""
A confirmed invoice paid in part at the till, and the rest paid later
("repayment"): every figure — the invoice's due, the customer's balance, the
cash reports, the bank — must count each rupee exactly once, and deleting or
cancelling the invoice must not make the customer's repayment disappear.
"""
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from banking.models import BankAccount, BankTransaction
from parties.models import Party, PartyPayment
from sales.models import Sale


class RepaymentTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(owner)
        self.ram = Party.objects.create(business=self.business, name="Ram")
        self.today = timezone.localdate().isoformat()

    # ── helpers ──
    def sell(self, paid, total_qty=10, method="CASH", number="INV-1", **extra):
        res = self.api.post("/api/sales/", {
            "customer": self.ram.id, "invoice_number": number, "sale_date": self.today,
            "payment_method": method, "paid_amount": str(paid), "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": str(total_qty), "unit_price": "100"}], **extra,
        }, format="json")
        return res

    def repay(self, amount, method="CASH", **extra):
        res = self.api.post("/api/parties/payments/", {
            "party": self.ram.id, "payment_type": "IN", "amount": str(amount),
            "payment_method": method, "date": self.today, **extra,
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    def balance(self):
        rows = self.api.get("/api/parties/").data
        rows = rows["results"] if isinstance(rows, dict) else rows
        return Decimal(next(r for r in rows if r["id"] == self.ram.id)["balance"])

    def due(self, sale_id):
        return Sale.objects.get(pk=sale_id).due_amount

    # ── paying more than the total is an advance; paid can't drop below repayments ──
    def test_paying_more_than_the_total_records_an_advance(self):
        res = self.sell(paid=1200)  # total is 1000
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(self.due(res.data["id"]), Decimal("-200"))
        self.assertEqual(self.balance(), Decimal("-200"))  # Ram has Rs 200 credit with us

    def test_cutting_the_total_below_what_was_paid_turns_the_rest_into_an_advance(self):
        sale = self.sell(paid=800).data
        res = self.api.patch(f"/api/sales/{sale['id']}/", {
            "items": [{"product_name": "Rice", "quantity": "5", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.due(sale["id"]), Decimal("-300"))
        self.assertEqual(self.balance(), Decimal("-300"))

    def test_a_negative_paid_amount_is_refused(self):
        res = self.sell(paid=-5)
        self.assertEqual(res.status_code, 400)
        self.assertIn("can't be negative", str(res.data["paid_amount"]))

    def test_paid_cannot_be_cut_below_what_repayments_put_on_it(self):
        sale = self.sell(paid=300).data
        self.repay(500)
        res = self.api.patch(f"/api/sales/{sale['id']}/", {"paid_amount": "400"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("paid later through party payments", str(res.data["paid_amount"]))

    # ── the repayment survives the invoice going away ──
    def test_deleting_a_repaid_invoice_leaves_the_repayment_as_credit(self):
        sale = self.sell(paid=300).data
        self.repay(500)
        self.assertEqual(self.balance(), Decimal("200"))
        self.assertEqual(self.api.delete(f"/api/sales/{sale['id']}/").status_code, 204)
        self.assertEqual(self.balance(), Decimal("-500"))  # we owe Ram the 500 he paid later

    def test_cancelling_a_repaid_invoice_leaves_the_repayment_as_credit(self):
        sale = self.sell(paid=300).data
        self.repay(500)
        res = self.api.patch(f"/api/sales/{sale['id']}/", {"status": "CANCELLED"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.balance(), Decimal("-500"))

    # ── each rupee counted once in the cash reports ──
    def test_cash_reports_count_a_cash_repayment_once(self):
        self.sell(paid=300)
        self.repay(500)
        dashboard = self.api.get("/api/reports/dashboard/").data
        self.assertEqual(dashboard["cash_balance"], 800)
        self.assertEqual(dashboard["collection_today"], 800)
        day_book = self.api.get("/api/reports/day-book/", {"date": self.today}).data
        self.assertEqual(day_book["total_in"], 800)
        cash = self.api.get("/api/reports/cash-in-hand/").data
        self.assertEqual(cash["closing_balance"], 800)

    def test_editing_a_bank_invoice_after_a_bank_repayment_does_not_double_the_bank(self):
        account = BankAccount.objects.create(business=self.business, bank_name="NIC", account_name="Shop")
        sale = self.sell(paid=300, method="BANK", bank_account=account.id).data
        self.repay(500, method="BANK", bank_account=account.id)
        self.api.patch(f"/api/sales/{sale['id']}/", {"notes": "called Ram"}, format="json")
        sale_txn = BankTransaction.objects.get(reference=f"SALE-{sale['id']}")
        self.assertEqual(sale_txn.amount, Decimal("300"))

    # ── Receive payment on one specific invoice ──
    def test_receive_payment_settles_the_chosen_invoice_not_the_oldest(self):
        older = self.sell(paid=0, number="INV-1").data
        newer = self.sell(paid=0, number="INV-2").data
        res = self.api.post(f"/api/sales/{newer['id']}/receive-payment/", {
            "amount": "400", "payment_method": "CASH", "date": self.today,
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(self.due(newer["id"]), Decimal("600"))
        self.assertEqual(self.due(older["id"]), Decimal("1000"))
        self.assertEqual(self.balance(), Decimal("1600"))
        payment = PartyPayment.objects.get(pk=res.data["payment_id"])
        self.assertEqual((payment.party_id, payment.amount), (self.ram.id, Decimal("400")))
        self.assertEqual(self.api.get("/api/reports/dashboard/").data["cash_balance"], 400)

    def test_receive_payment_refuses_more_than_is_due_or_nothing(self):
        sale = self.sell(paid=900).data
        url = f"/api/sales/{sale['id']}/receive-payment/"
        self.assertEqual(self.api.post(url, {"amount": "150", "date": self.today}, format="json").status_code, 400)
        self.assertEqual(self.api.post(url, {"amount": "0", "date": self.today}, format="json").status_code, 400)
        self.assertEqual(self.api.post(url, {"amount": "100", "date": self.today}, format="json").status_code, 201)
        self.assertEqual(self.due(sale["id"]), Decimal("0"))

    def test_receive_payment_needs_a_customer(self):
        res = self.api.post("/api/sales/", {
            "invoice_number": "WALK-1", "sale_date": self.today, "payment_method": "CASH",
            "paid_amount": "0", "status": "CONFIRMED",
            "items": [{"product_name": "Rice", "quantity": "1", "unit_price": "100"}],
        }, format="json")
        paid = self.api.post(f"/api/sales/{res.data['id']}/receive-payment/",
                             {"amount": "50", "date": self.today}, format="json")
        self.assertEqual(paid.status_code, 400)
        self.assertIn("customer", paid.data["message"])
