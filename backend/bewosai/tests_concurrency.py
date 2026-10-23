"""
Double-taps and two staff at once: the same write sent twice at the same moment
must change money and stock once, never twice (see bewosai/locking.py).

Each test sends two identical requests from two threads, with a short pause
inside the first so they truly overlap, then checks the books. Needs Postgres —
SQLite has no row locks, and the bugs these guard against can't happen on it in
the same way — so they're skipped on SQLite. Run with e.g.
    DATABASE_URL=pgsql://postgres:test@127.0.0.1:55432/bewosai python manage.py test bewosai.tests_concurrency
"""
import threading
import time
import unittest
from datetime import date
from decimal import Decimal
from unittest import mock

from django.db import connection, connections
from django.test import TransactionTestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory import stock
from inventory.models import Product
from parties.models import Party, PaymentAllocation
from parties.views import PartyPaymentListCreateView
from sales.models import Sale, SaleItem

D = lambda x: Decimal(str(x))  # noqa: E731


def _slowed(func, seconds=0.4):
    """`func`, but the first call pauses first — holds the first request open
    long enough for the second one to arrive mid-way."""
    first = threading.Event()

    def wrapper(*args, **kwargs):
        if not first.is_set():
            first.set()
            time.sleep(seconds)
        return func(*args, **kwargs)
    return wrapper


@unittest.skipUnless(connection.vendor == "postgresql", "row locks need Postgres")
class DoubleTapTests(TransactionTestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.product = Product.objects.create(
            business=self.business, name="Rice", sale_price=D(100), purchase_price=D(60), stock_quantity=D(10),
        )
        self.customer = Party.objects.create(business=self.business, name="Ram")

    def api_client(self):
        api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        api.force_authenticate(self.owner)
        return api

    def make_sale(self, qty=4, price=250, paid=0, **extra):
        sale = Sale.objects.create(
            business=self.business, customer=self.customer, invoice_number=f"S{Sale.objects.count() + 1}",
            sale_date=date(2026, 9, 1), subtotal=D(qty * price), paid_amount=D(paid), **extra,
        )
        SaleItem.objects.create(
            sale=sale, product=self.product, product_name="Rice", quantity=D(qty), unit_price=D(price),
        )
        sale.save()
        return sale

    def twice(self, send):
        """Run send(client) in two threads at once; return both responses' status codes."""
        results, errors = [], []
        start = threading.Barrier(2)

        def run():
            try:
                start.wait()
                results.append(send(self.api_client()).status_code)
            except Exception as exc:  # surfaced below; a thread's exception is otherwise lost
                errors.append(exc)
            finally:
                connections.close_all()

        threads = [threading.Thread(target=run) for _ in range(2)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)
        if errors:
            raise errors[0]
        return sorted(results)

    def stock_now(self):
        self.product.refresh_from_db()
        return self.product.stock_quantity

    def test_double_tapped_delete_puts_stock_back_once(self):
        sale = self.make_sale(qty=4)
        Product.objects.filter(pk=self.product.pk).update(stock_quantity=D(6))   # 10 - 4 sold
        with mock.patch.object(stock, "_change", _slowed(stock._change)):
            codes = self.twice(lambda api: api.delete(f"/api/sales/{sale.id}/"))
        self.assertEqual(codes, [204, 404])
        self.assertEqual(self.stock_now(), D(10))

    def test_double_tapped_receive_payment_pays_once(self):
        sale = self.make_sale()           # Rs 1000 due
        slowed = _slowed(PartyPaymentListCreateView._reconcile_payment)
        with mock.patch.object(PartyPaymentListCreateView, "_reconcile_payment", staticmethod(slowed)):
            codes = self.twice(lambda api: api.post(
                f"/api/sales/{sale.id}/receive-payment/", {"amount": "1000"}, format="json",
            ))
        self.assertEqual(codes, [201, 400])
        sale.refresh_from_db()
        self.assertEqual(sale.paid_amount, D(1000))
        self.assertEqual(sale.due_amount, D(0))
        self.assertEqual(self.customer.payments.filter(is_deleted=False).count(), 1)

    def test_two_payments_at_once_never_overpay_an_invoice(self):
        sale = self.make_sale()           # Rs 1000 due
        slowed = _slowed(PartyPaymentListCreateView._reconcile_payment)
        with mock.patch.object(PartyPaymentListCreateView, "_reconcile_payment", staticmethod(slowed)):
            codes = self.twice(lambda api: api.post("/api/parties/payments/", {
                "party": self.customer.id, "payment_type": "IN", "amount": "1000",
                "payment_method": "CASH", "date": "2026-09-02",
            }, format="json"))
        self.assertEqual(codes, [201, 201])   # two real payments: the second is the customer's credit
        sale.refresh_from_db()
        allocated = sum(a.amount for a in PaymentAllocation.objects.filter(sale=sale))
        self.assertEqual(sale.paid_amount, D(1000))
        self.assertEqual(allocated, D(1000))

    def test_double_tapped_restore_applies_stock_once(self):
        sale = self.make_sale(qty=4)
        Sale.objects.filter(pk=sale.pk).update(is_deleted=True)   # deleted: stock back at 10
        with mock.patch.object(stock, "_change", _slowed(stock._change)):
            codes = self.twice(lambda api: api.post(f"/api/purchases/recycle-bin/restore/sale/{sale.id}/"))
        self.assertEqual(codes, [200, 404])
        self.assertEqual(self.stock_now(), D(6))
