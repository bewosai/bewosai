from datetime import date, timedelta

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import Business, FiscalYear, StaffMember, User
from sales.models import Sale


def make_business(email, name, fiscal_year_start="01-01"):
    user = User.objects.create_user(email=email, name=name)
    business = Business.objects.create(owner=user, name=f"{name} Biz", fiscal_year_start=fiscal_year_start)
    StaffMember.objects.create(user=user, business=business, role=StaffMember.ROLE_OWNER)
    return user, business


class CloseFiscalYearViewTests(TestCase):
    """Phase 1: closing records the period in place — no archiving/cloning."""

    def setUp(self):
        self.owner, self.business = make_business("fy@example.com", "FiscalYear", fiscal_year_start="01-01")
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def test_close_creates_fiscal_year_without_archiving_business(self):
        r = self.client.post(f"/api/auth/businesses/{self.business.id}/close-fiscal-year/")
        self.assertEqual(r.status_code, 201, r.content)

        self.business.refresh_from_db()
        self.assertEqual(self.business.status, Business.STATUS_ACTIVE)  # not archived
        self.assertEqual(Business.objects.count(), 1)  # nothing cloned

        fy = FiscalYear.objects.get(business=self.business)
        self.assertEqual(fy.status, FiscalYear.STATUS_CLOSED)
        self.assertEqual(fy.closed_by, self.owner)

    def test_cannot_close_the_same_period_twice(self):
        self.client.post(f"/api/auth/businesses/{self.business.id}/close-fiscal-year/")
        r = self.client.post(f"/api/auth/businesses/{self.business.id}/close-fiscal-year/")
        self.assertEqual(r.status_code, 400)

    def test_fiscal_years_list_is_read_only_and_scoped_to_owner(self):
        self.client.post(f"/api/auth/businesses/{self.business.id}/close-fiscal-year/")
        r = self.client.get(f"/api/auth/businesses/{self.business.id}/fiscal-years/")
        self.assertEqual(r.status_code, 200)
        results = r.data.get("results", r.data)
        self.assertEqual(len(results), 1)

        other_owner, _ = make_business("other-fy@example.com", "Other")
        other_client = APIClient()
        other_client.force_authenticate(user=other_owner)
        r = other_client.get(f"/api/auth/businesses/{self.business.id}/fiscal-years/")
        self.assertEqual(len(r.data.get("results", r.data)), 0)  # scoped, not another owner's data


@override_settings(ALLOWED_HOSTS=["testserver"])
class FiscalYearLockedTests(TestCase):
    """Phase 2: a record dated inside a CLOSED fiscal year becomes
    read-only — view/search still work, edits/deletes are rejected."""

    def setUp(self):
        self.owner, self.business = make_business("lock@example.com", "Lock", fiscal_year_start="01-01")
        self.headers = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

        self.old_sale = Sale.objects.create(
            business=self.business, invoice_number="INV-OLD", sale_date=date(2024, 6, 15),
        )
        self.new_sale = Sale.objects.create(
            business=self.business, invoice_number="INV-NEW", sale_date=date(2026, 6, 15),
        )
        # Close the 2024 calendar year (fiscal_year_start="01-01" means the
        # fiscal year is the plain calendar year) — covers old_sale, not new_sale.
        FiscalYear.objects.create(
            business=self.business, start_date=date(2024, 1, 1), end_date=date(2024, 12, 31),
            label="2024", status=FiscalYear.STATUS_CLOSED, closed_by=self.owner,
        )

    def test_get_on_locked_record_still_works(self):
        r = self.client.get(f"/api/sales/{self.old_sale.id}/", **self.headers)
        self.assertEqual(r.status_code, 200)

    def test_patch_on_locked_record_is_rejected(self):
        r = self.client.patch(f"/api/sales/{self.old_sale.id}/", {"notes": "edited"}, format="json", **self.headers)
        self.assertEqual(r.status_code, 403)
        self.assertIn("2024", r.data.get("detail", ""))

    def test_delete_on_locked_record_is_rejected(self):
        r = self.client.delete(f"/api/sales/{self.old_sale.id}/", **self.headers)
        self.assertEqual(r.status_code, 403)

    def test_patch_on_record_outside_closed_period_still_works(self):
        r = self.client.patch(f"/api/sales/{self.new_sale.id}/", {"notes": "edited"}, format="json", **self.headers)
        self.assertEqual(r.status_code, 200, r.content)
        self.new_sale.refresh_from_db()
        self.assertEqual(self.new_sale.notes, "edited")

    def test_reopening_the_period_lifts_the_lock(self):
        FiscalYear.objects.filter(business=self.business, label="2024").update(status=FiscalYear.STATUS_ACTIVE)
        r = self.client.patch(f"/api/sales/{self.old_sale.id}/", {"notes": "edited"}, format="json", **self.headers)
        self.assertEqual(r.status_code, 200, r.content)
