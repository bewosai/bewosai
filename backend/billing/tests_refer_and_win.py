"""
Refer & Win, and business-profile limits per plan:

- a referral code works for new accounts only (under NEW_USER_DAYS old, never
  referred before, not your own), whether typed at business creation or into
  the "Have a coupon?" box;
- both sides get a month of Premium, but only once the new user has verified a
  sign-in — until then it waits, and pays out at that sign-in;
- Free = 2 business profiles, Premium = 3, Premium Plus = 5.
"""
from datetime import timedelta
from unittest import mock

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, OTPCode, User
from .models import Referral
from .services import NEW_USER_DAYS, _extend_and_grant, process_referral
from .tests import make_business


class ReferralForNewUsersTests(TestCase):
    def setUp(self):
        self.referrer_owner, self.referrer = make_business("ref@example.com", "Referrer")

    def api_for(self, user, business):
        api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        api.force_authenticate(user)
        return api

    def test_a_new_user_can_apply_a_friends_code_in_the_coupon_box(self):
        owner, business = make_business("new@example.com", "New")
        res = self.api_for(owner, business).post(
            "/api/billing/apply-coupon/", {"code": self.referrer.referral_code.lower()}, format="json",
        )
        self.assertEqual(res.status_code, 200, res.content)
        self.assertIn("Premium active until", res.data["message"])
        today = timezone.localdate()
        for b in (business, self.referrer):
            b.refresh_from_db()
            self.assertEqual(b.effective_plan, Business.PLAN_PREMIUM)
            self.assertEqual((b.active_referral_subscription.end_date - today).days, 30)

    def test_an_older_account_cannot_use_a_referral_code(self):
        owner, business = make_business("old@example.com", "Old")
        User.objects.filter(pk=owner.pk).update(created_at=timezone.now() - timedelta(days=NEW_USER_DAYS + 1))
        owner.refresh_from_db()
        res = self.api_for(owner, business).post(
            "/api/billing/apply-coupon/", {"code": self.referrer.referral_code}, format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data["message"], "Referral codes are for new accounts only.")
        self.assertEqual(self.referrer.effective_plan, Business.PLAN_FREE)

    def test_one_referral_per_account_even_across_businesses(self):
        owner, first = make_business("twice@example.com", "Twice")
        other_referrer = make_business("ref2@example.com", "Ref2")[1]
        self.assertEqual(process_referral(new_business=first, referrer_business=self.referrer).status,
                         Referral.STATUS_REWARDED)
        second = Business.objects.create(owner=owner, name="Second")
        referral = process_referral(new_business=second, referrer_business=other_referrer)
        self.assertEqual(referral.status, Referral.STATUS_REJECTED)
        self.assertEqual(referral.reject_reason, "This account has already used a referral code.")

    def test_your_own_code_is_refused_and_does_not_block_a_friends_code(self):
        owner, business = make_business("self@example.com", "Self")
        api = self.api_for(owner, business)
        own = Business.objects.create(owner=owner, name="My other shop")
        self.assertEqual(api.post("/api/billing/apply-coupon/", {"code": own.referral_code}, format="json").status_code, 400)
        res = api.post("/api/billing/apply-coupon/", {"code": self.referrer.referral_code}, format="json")
        self.assertEqual(res.status_code, 200, res.content)

    def test_the_reward_waits_until_the_new_user_verifies_a_sign_in(self):
        owner, business = make_business("unverified@example.com", "Unverified", verified=False)
        referral = process_referral(new_business=business, referrer_business=self.referrer)
        self.assertEqual(referral.status, Referral.STATUS_REGISTERED)
        self.assertEqual(business.effective_plan, Business.PLAN_FREE)
        self.assertEqual(self.referrer.effective_plan, Business.PLAN_FREE)

        _, code = OTPCode.generate(owner.email, owner.account_type)
        with mock.patch("accounts.views.send_otp_email", return_value=True):
            res = APIClient().post("/api/auth/verify-otp/", {"identifier": owner.email, "code": code}, format="json")
        self.assertEqual(res.status_code, 200, res.content)

        referral.refresh_from_db()
        self.assertEqual(referral.status, Referral.STATUS_REWARDED)
        self.assertEqual(business.effective_plan, Business.PLAN_PREMIUM)
        self.assertEqual(self.referrer.effective_plan, Business.PLAN_PREMIUM)


class BusinessProfileLimitTests(TestCase):
    def create(self, api, n):
        return api.post("/api/auth/businesses/", {"name": f"Shop {n}"}, format="json")

    def fill_to_limit(self, plan, platform="web"):
        owner, business = make_business(f"{plan.lower()}{platform}@example.com", plan)
        if plan != Business.PLAN_FREE:
            _extend_and_grant(business=business, plan=plan, coupon_user=owner)
        api = APIClient(HTTP_X_PLATFORM=platform)
        api.force_authenticate(owner)
        created = 1
        while self.create(api, created).status_code == 201:
            created += 1
            self.assertLess(created, 20)
        return created, self.create(api, 99)

    # Limits depend on where the business is added from, not on the plan.
    def test_the_website_allows_five_on_any_plan(self):
        for plan in (Business.PLAN_FREE, Business.PLAN_PREMIUM, Business.PLAN_PREMIUMPLUS):
            count, refused = self.fill_to_limit(plan)
            self.assertEqual(count, 5, plan)
            self.assertIn("up to 5 business profiles", refused.data["error"])

    def test_the_app_allows_three_on_any_plan(self):
        for plan in (Business.PLAN_FREE, Business.PLAN_PREMIUMPLUS):
            count, refused = self.fill_to_limit(plan, platform="mobile")
            self.assertEqual(count, 3, plan)
            self.assertIn("5 on the website", refused.data["error"])

    def test_a_super_admin_override_still_wins(self):
        owner, _ = make_business("override@example.com", Business.PLAN_FREE)
        owner.business_limit_override = 7
        owner.save()
        api = APIClient(HTTP_X_PLATFORM="mobile")
        api.force_authenticate(owner)
        created = 1
        while self.create(api, created).status_code == 201:
            created += 1
        self.assertEqual(created, 7)

    def test_the_upgrade_page_shows_the_same_limit(self):
        owner, business = make_business("usage@example.com", "Usage")
        _extend_and_grant(business=business, plan=Business.PLAN_PREMIUM, coupon_user=owner)
        api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        api.force_authenticate(owner)
        data = api.get("/api/billing/subscription/").data
        self.assertEqual((data["business_count"], data["business_limit"]), (1, 5))
        app = APIClient(HTTP_X_BUSINESS_ID=str(business.id), HTTP_X_PLATFORM="mobile")
        app.force_authenticate(owner)
        data = app.get("/api/billing/subscription/").data
        self.assertEqual((data["business_limit"], data["staff_limit"]), (3, 3))
