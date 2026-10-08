"""
A coupon made in Super Admin for Premium activates exactly Premium, one for
Premium Plus exactly Premium Plus, and Super Admin can see who used which
coupon, when, and on which business.
"""
from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, User
from .tests import make_business


class CouponPlanAndTrackingTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_user(email="sa@example.com", name="SA", is_platform_admin=True)
        self.admin_api = APIClient()
        self.admin_api.force_authenticate(self.admin)

    def make_coupon(self, user, plan):
        res = self.admin_api.post(
            "/api/superadmin/coupons/", {"user": user.id, "plan": plan, "end_date": "2099-01-01"}, format="json",
        )
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(res.data["plan"], plan)
        return res.data["code"]

    def apply(self, user, business, code):
        api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        api.force_authenticate(user)
        return api, api.post("/api/billing/apply-coupon/", {"code": code}, format="json")

    def check_plan(self, plan, business_limit):
        owner, business = make_business(f"{plan.lower()}@example.com", plan)
        api, res = self.apply(owner, business, self.make_coupon(owner, plan))
        self.assertEqual(res.status_code, 200, res.content)
        sub = api.get("/api/billing/subscription/").data
        self.assertEqual(sub["effective_plan"], plan)
        self.assertEqual(sub["business_limit"], business_limit)  # 5 on the website, whatever the plan
        return owner, business

    def test_a_premium_coupon_activates_premium(self):
        self.check_plan(Business.PLAN_PREMIUM, 5)

    def test_a_premium_plus_coupon_activates_premium_plus(self):
        self.check_plan(Business.PLAN_PREMIUMPLUS, 5)

    def test_super_admin_sees_who_used_which_coupon(self):
        owner, business = self.check_plan(Business.PLAN_PREMIUM, 5)
        unused_for = make_business("waiting@example.com", "Waiting")[0]
        unused_code = self.make_coupon(unused_for, Business.PLAN_PREMIUMPLUS)

        rows = {r["code"]: r for r in self.admin_api.get("/api/superadmin/coupons/").data["results"]}
        used = next(r for r in rows.values() if r["user_email"] == owner.email)
        self.assertEqual(used["status"], "USED")
        self.assertIsNotNone(used["used_at"])
        self.assertEqual(used["used_for_business_name"], business.name)
        self.assertEqual(used["plan"], Business.PLAN_PREMIUM)

        waiting = rows[unused_code]
        self.assertEqual(waiting["status"], "ACTIVE")
        self.assertIsNone(waiting["used_at"])
        self.assertEqual(waiting["user_email"], "waiting@example.com")

        only_used = self.admin_api.get("/api/superadmin/coupons/", {"status": "USED"}).data["results"]
        self.assertEqual([r["user_email"] for r in only_used], [owner.email])

    def test_a_made_up_code_activates_nothing(self):
        owner, business = make_business("fake@example.com", "Fake")
        api, res = self.apply(owner, business, "ABCDEF")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data["message"], "Invalid coupon code.")
        self.assertEqual(api.get("/api/billing/subscription/").data["effective_plan"], Business.PLAN_FREE)
