from datetime import date, datetime, timezone as dt_timezone
from decimal import Decimal
from unittest import mock

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import User, Business, StaffMember
from sales.models import Sale


class NepalTodayTests(TestCase):
    """The business runs on Nepal time (Asia/Kathmandu, UTC+5:45). Between
    midnight and 5:45 AM there, it's already tomorrow compared to UTC — the
    dashboard's "today" must follow Nepal, not UTC."""

    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.owner, name="Shop")
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def _dashboard_at(self, utc_moment):
        with mock.patch("django.utils.timezone.now", return_value=utc_moment):
            res = self.client.get("/api/reports/dashboard/", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.assertEqual(res.status_code, 200, res.content)
        return res.data

    def test_early_morning_nepal_time_counts_todays_sales(self):
        Sale.objects.create(
            business=self.business, invoice_number="S1", sale_date=date(2026, 9, 18),
            subtotal=Decimal("500"), status="CONFIRMED",
        )
        # 20:00 UTC on the 17th = 01:45 on the 18th in Nepal.
        data = self._dashboard_at(datetime(2026, 9, 17, 20, 0, tzinfo=dt_timezone.utc))
        self.assertEqual(Decimal(str(data["sales_today"])), Decimal("500"))

    def test_late_evening_nepal_time_does_not_pull_in_tomorrows_sales(self):
        Sale.objects.create(
            business=self.business, invoice_number="S2", sale_date=date(2026, 9, 19),
            subtotal=Decimal("700"), status="CONFIRMED",
        )
        # 17:00 UTC on the 18th = 22:45 on the 18th in Nepal: the 19th hasn't started.
        data = self._dashboard_at(datetime(2026, 9, 18, 17, 0, tzinfo=dt_timezone.utc))
        self.assertEqual(Decimal(str(data["sales_today"])), Decimal("0"))
