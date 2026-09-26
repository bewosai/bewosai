"""
Partial payments end to end through the API, the way the app and website use
them: a sale paid in part at the till, the rest paid later in instalments
(one of them more than was owed), a payment corrected after the fact, one
deleted — and at every step the invoice's due, the party's balance and the
due-reminder list all have to agree.
"""
from datetime import date
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from sales.models import Sale
from .models import Party


class PartialPaymentTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient()
        self.api.force_authenticate(owner)
        self.h = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        self.ram = Party.objects.create(business=self.business, name="Ram")
        # Rs 1000 sale, Rs 300 paid at the till → Rs 700 due.
        self.sale = Sale.objects.create(
            business=self.business, customer=self.ram, invoice_number="INV-1", sale_date=date(2026, 9, 1),
            subtotal=Decimal("1000"), paid_amount=Decimal("300"), status="CONFIRMED",
        )

    def pay(self, amount, payment_type="IN"):
        res = self.api.post("/api/parties/payments/", {
            "party": self.ram.id, "payment_type": payment_type, "amount": str(amount),
            "payment_method": "CASH", "date": "2026-09-10",
        }, format="json", **self.h)
        self.assertEqual(res.status_code, 201, res.content)
        return res.data["id"]

    def due(self):
        self.sale.refresh_from_db()
        return self.sale.due_amount

    def balance(self):
        rows = self.api.get("/api/parties/", **self.h).data
        rows = rows["results"] if isinstance(rows, dict) else rows
        return Decimal(next(r for r in rows if r["id"] == self.ram.id)["balance"])

    def reminder_list(self):
        rows = self.api.get("/api/sales/", {"has_due": "true"}, **self.h).data
        rows = rows["results"] if isinstance(rows, dict) else rows
        return [r["invoice_number"] for r in rows]

    def test_instalments_overpayment_correction_and_delete_all_stay_consistent(self):
        self.assertEqual(self.due(), Decimal("700"))
        self.assertEqual(self.balance(), Decimal("700"))
        self.assertEqual(self.reminder_list(), ["INV-1"])

        first = self.pay(200)
        self.assertEqual(self.due(), Decimal("500"))
        self.assertEqual(self.balance(), Decimal("500"))

        # Pays Rs 800 against Rs 500 due: invoice cleared, Rs 300 kept as advance.
        second = self.pay(800)
        self.assertEqual(self.due(), Decimal("0"))
        self.assertEqual(self.balance(), Decimal("-300"))
        self.assertEqual(self.reminder_list(), [])

        # The first instalment was really Rs 100, not 200 — corrected afterwards.
        # Received in total: 300 + 100 + 800 = 1200 against 1000 → Rs 200 advance.
        res = self.api.patch(f"/api/parties/payments/{first}/", {"amount": "100"}, format="json", **self.h)
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.balance(), Decimal("-200"))
        self.assertGreaterEqual(self.due(), Decimal("0"))

        # The Rs 800 payment was entered by mistake. Received: 300 + 100 = 400 → Rs 600 due.
        res = self.api.delete(f"/api/parties/payments/{second}/", **self.h)
        self.assertEqual(res.status_code, 204, res.content)
        self.assertEqual(self.due(), Decimal("600"))
        self.assertEqual(self.balance(), Decimal("600"))
        self.assertEqual(self.reminder_list(), ["INV-1"])

    def test_raising_a_payment_applies_the_extra_to_the_invoice(self):
        first = self.pay(200)
        self.api.patch(f"/api/parties/payments/{first}/", {"amount": "700"}, format="json", **self.h)
        self.assertEqual(self.due(), Decimal("0"))
        self.assertEqual(self.balance(), Decimal("0"))

    def test_changing_a_payment_to_another_party_moves_it(self):
        sita = Party.objects.create(business=self.business, name="Sita")
        first = self.pay(200)
        self.api.patch(f"/api/parties/payments/{first}/", {"party": sita.id}, format="json", **self.h)
        # Ram owes the full Rs 700 again; Sita now has Rs 200 on account.
        self.assertEqual(self.due(), Decimal("700"))
        self.assertEqual(self.balance(), Decimal("700"))

    def test_a_reminder_is_saved_and_listed_with_its_note(self):
        res = self.api.patch(f"/api/sales/{self.sale.id}/", {
            "reminder_enabled": True, "reminder_at": "2026-09-30T10:00:00+05:45",
            "reminder_note": "Promised to pay by month end",
        }, format="json", **self.h)
        self.assertEqual(res.status_code, 200, res.content)
        row = self.api.get(f"/api/sales/{self.sale.id}/", **self.h).data
        self.assertTrue(row["reminder_enabled"])
        self.assertEqual(row["reminder_note"], "Promised to pay by month end")
        self.assertEqual(Decimal(row["due_amount"]), Decimal("700"))
        # Updating only the reminder must not touch what's owed.
        self.assertEqual(self.due(), Decimal("700"))
