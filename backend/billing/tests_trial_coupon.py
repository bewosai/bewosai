"""
The path a real customer takes once the free trial is over: every business
screen is blocked, they type a Premium coupon into the locked screen, and the
business is Premium and usable again straight away — no license, no re-login.
"""
from datetime import date, datetime, timedelta
from unittest import mock

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business
from .models import Coupon
from .tests import make_business

# Well after a business created on 2026-09-01 finished its 90-day trial.
LATER = date(2027, 1, 15)


class CouponAfterTrialEndsTests(TestCase):
    def setUp(self):
        self.owner, self.business = make_business("trial@example.com", "Trial")
        Business.objects.filter(pk=self.business.pk).update(created_at=timezone.make_aware(datetime(2026, 9, 1)))
        self.api = APIClient()
        self.api.force_authenticate(self.owner)
        self.headers = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        patcher = mock.patch("django.utils.timezone.localdate", return_value=LATER)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_a_coupon_unlocks_a_business_whose_trial_has_ended(self):
        self.assertEqual(self.api.get("/api/parties/", **self.headers).status_code, 403)
        status_before = self.api.get("/api/auth/licenses/me/", **self.headers).data
        self.assertFalse(status_before["has_active_subscription"])
        self.assertEqual(status_before["effective_plan"], Business.PLAN_FREE)

        coupon = Coupon.generate(
            user=self.owner, plan=Business.PLAN_PREMIUM, start_date=LATER, end_date=LATER + timedelta(days=30),
        )
        res = self.api.post("/api/billing/apply-coupon/", {"code": coupon.code.lower()}, format="json", **self.headers)
        self.assertEqual(res.status_code, 200, res.content)

        status_after = self.api.get("/api/auth/licenses/me/", **self.headers).data
        self.assertTrue(status_after["has_active_subscription"])
        self.assertEqual(status_after["effective_plan"], Business.PLAN_PREMIUM)
        self.assertEqual(self.api.get("/api/parties/", **self.headers).status_code, 200)

        # The business list the apps refresh after a coupon now reports Premium.
        listed = self.api.get("/api/auth/businesses/").data
        rows = listed["results"] if isinstance(listed, dict) else listed
        self.assertEqual(rows[0]["effective_plan"], Business.PLAN_PREMIUM)

    def test_a_wrong_code_keeps_the_business_locked_with_a_plain_message(self):
        res = self.api.post("/api/billing/apply-coupon/", {"code": "ZZZZZZ"}, format="json", **self.headers)
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data["message"], "Invalid coupon code.")
        self.assertEqual(self.api.get("/api/parties/", **self.headers).status_code, 403)
