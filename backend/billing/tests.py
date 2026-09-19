from datetime import date, timedelta
from unittest import mock

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from .models import Coupon, Referral, Subscription
from .services import CouponError, apply_coupon, process_referral


def make_business(email, name):
    user = User.objects.create_user(email=email, name=name)
    business = Business.objects.create(owner=user, name=f"{name} Biz")
    StaffMember.objects.create(user=user, business=business, role=StaffMember.ROLE_OWNER)
    return user, business


class CouponStatusTests(TestCase):
    def setUp(self):
        self.user, self.business = make_business("coupon@example.com", "Coupon")

    def _coupon(self, **overrides):
        today = timezone.localdate()
        defaults = dict(
            user=self.user, plan=Business.PLAN_PREMIUM,
            start_date=today, end_date=today + timedelta(days=30),
        )
        defaults.update(overrides)
        return Coupon.generate(**defaults)

    def test_active_by_default(self):
        self.assertEqual(self._coupon().computed_status, "ACTIVE")

    def test_expired_past_end_date(self):
        today = timezone.localdate()
        coupon = self._coupon(start_date=today - timedelta(days=60), end_date=today - timedelta(days=1))
        self.assertEqual(coupon.computed_status, "EXPIRED")

    def test_cancelled_when_deactivated(self):
        coupon = self._coupon()
        coupon.is_active = False
        coupon.save()
        self.assertEqual(coupon.computed_status, "CANCELLED")

    def test_used_overrides_active(self):
        coupon = self._coupon()
        coupon.is_used = True
        coupon.save()
        self.assertEqual(coupon.computed_status, "USED")

    def test_cancelled_wins_over_used(self):
        """is_active=False should read as CANCELLED even if it was also
        used — matches the spec's "never trust is_active alone, but it's
        still the first-checked signal" ordering."""
        coupon = self._coupon()
        coupon.is_used = True
        coupon.is_active = False
        coupon.save()
        self.assertEqual(coupon.computed_status, "CANCELLED")


class ApplyCouponTests(TestCase):
    def setUp(self):
        self.owner, self.business = make_business("apply@example.com", "Apply")
        self.other_owner, self.other_business = make_business("other@example.com", "Other")
        today = timezone.localdate()
        self.coupon = Coupon.generate(
            user=self.owner, plan=Business.PLAN_PREMIUMPLUS,
            start_date=today, end_date=today + timedelta(days=30),
        )

    def test_correct_user_can_apply(self):
        sub = apply_coupon(code=self.coupon.code, user=self.owner, business=self.business)
        self.assertEqual(sub.plan, Business.PLAN_PREMIUMPLUS)
        self.assertEqual(sub.status, Subscription.STATUS_ACTIVE)
        self.coupon.refresh_from_db()
        self.assertTrue(self.coupon.is_used)
        self.assertEqual(self.coupon.used_for_business, self.business)
        self.assertEqual(self.business.effective_plan, Business.PLAN_PREMIUMPLUS)

    def test_wrong_user_rejected(self):
        with self.assertRaises(CouponError):
            apply_coupon(code=self.coupon.code, user=self.other_owner, business=self.other_business)
        self.coupon.refresh_from_db()
        self.assertFalse(self.coupon.is_used)

    def test_already_used_rejected(self):
        apply_coupon(code=self.coupon.code, user=self.owner, business=self.business)
        with self.assertRaises(CouponError):
            apply_coupon(code=self.coupon.code, user=self.owner, business=self.business)

    def test_expired_rejected(self):
        today = timezone.localdate()
        expired = Coupon.generate(
            user=self.owner, plan=Business.PLAN_PREMIUM,
            start_date=today - timedelta(days=60), end_date=today - timedelta(days=1),
        )
        with self.assertRaises(CouponError):
            apply_coupon(code=expired.code, user=self.owner, business=self.business)

    def test_cancelled_rejected(self):
        self.coupon.is_active = False
        self.coupon.save()
        with self.assertRaises(CouponError):
            apply_coupon(code=self.coupon.code, user=self.owner, business=self.business)

    def test_invalid_code_rejected(self):
        with self.assertRaises(CouponError):
            apply_coupon(code="ZZZZZZ", user=self.owner, business=self.business)


class ReferralTests(TestCase):
    def setUp(self):
        self.referrer_owner, self.referrer_business = make_business("referrer@example.com", "Referrer")
        self.new_owner, self.new_business = make_business("newuser@example.com", "NewUser")

    def test_successful_referral_rewards_both_sides_premium(self):
        referral = process_referral(new_business=self.new_business, referrer_business=self.referrer_business)
        self.assertEqual(referral.status, Referral.STATUS_REWARDED)
        self.assertEqual(referral.referrer_subscription.plan, Business.PLAN_PREMIUM)
        self.assertEqual(referral.referred_subscription.plan, Business.PLAN_PREMIUM)
        self.assertEqual(self.referrer_business.effective_plan, Business.PLAN_PREMIUM)
        self.assertEqual(self.new_business.effective_plan, Business.PLAN_PREMIUM)

    def test_referrer_reward_mirrors_their_own_premiumplus_tier(self):
        """A PremiumPlus referrer's own reward should also be PremiumPlus —
        not downgraded to plain Premium — while the new signup still only
        ever gets Premium."""
        today = timezone.localdate()
        Coupon.generate(
            user=self.referrer_owner, plan=Business.PLAN_PREMIUMPLUS,
            start_date=today, end_date=today + timedelta(days=30),
        )
        apply_coupon(
            code=Coupon.objects.filter(user=self.referrer_owner).latest("created_at").code,
            user=self.referrer_owner, business=self.referrer_business,
        )
        self.assertEqual(self.referrer_business.effective_plan, Business.PLAN_PREMIUMPLUS)

        referral = process_referral(new_business=self.new_business, referrer_business=self.referrer_business)
        self.assertEqual(referral.referrer_subscription.plan, Business.PLAN_PREMIUMPLUS)
        self.assertEqual(referral.referred_subscription.plan, Business.PLAN_PREMIUM)

    def test_self_referral_rejected(self):
        second_business = Business.objects.create(owner=self.referrer_owner, name="Referrer's Second Biz")
        StaffMember.objects.create(user=self.referrer_owner, business=second_business, role=StaffMember.ROLE_OWNER)
        referral = process_referral(new_business=second_business, referrer_business=self.referrer_business)
        self.assertEqual(referral.status, Referral.STATUS_REJECTED)
        self.assertIsNone(referral.referrer_subscription)

    def test_same_account_cannot_double_claim(self):
        # Mirrors what BusinessListCreateView.perform_create actually does:
        # set referred_by *before* calling process_referral.
        self.new_business.referred_by = self.referrer_business
        self.new_business.save(update_fields=["referred_by"])
        process_referral(new_business=self.new_business, referrer_business=self.referrer_business)

        second_business = Business.objects.create(owner=self.new_owner, name="NewUser's Second Biz")
        StaffMember.objects.create(user=self.new_owner, business=second_business, role=StaffMember.ROLE_OWNER)
        second_business.referred_by = self.referrer_business
        second_business.save(update_fields=["referred_by"])

        referral = process_referral(new_business=second_business, referrer_business=self.referrer_business)
        self.assertEqual(referral.status, Referral.STATUS_REJECTED)

    def test_extends_existing_subscription_instead_of_overwriting(self):
        """Two referral rewards in a row should stack (extend from the
        current expiry), not reset back to today+30 each time."""
        first = process_referral(new_business=self.new_business, referrer_business=self.referrer_business)
        first_expiry = first.referrer_subscription.end_date

        third_owner, third_business = make_business("third@example.com", "Third")
        second = process_referral(new_business=third_business, referrer_business=self.referrer_business)
        self.assertGreater(second.referrer_subscription.end_date, first_expiry)


class EffectivePlanTests(TestCase):
    def test_active_subscription_raises_effective_plan_above_base(self):
        owner, business = make_business("plan@example.com", "Plan")
        self.assertEqual(business.effective_plan, Business.PLAN_FREE)

        today = timezone.localdate()
        coupon = Coupon.generate(
            user=owner, plan=Business.PLAN_PREMIUM, start_date=today, end_date=today + timedelta(days=30),
        )
        apply_coupon(code=coupon.code, user=owner, business=business)
        self.assertEqual(business.effective_plan, Business.PLAN_PREMIUM)
        self.assertTrue(business.has_active_subscription)

    def test_expired_subscription_does_not_count(self):
        owner, business = make_business("expired@example.com", "Expired")
        today = timezone.localdate()
        Subscription.objects.create(
            business=business, user=owner, plan=Business.PLAN_PREMIUM,
            status=Subscription.STATUS_ACTIVE, start_date=today - timedelta(days=60), end_date=today - timedelta(days=1),
            source=Coupon.SOURCE_ADMIN,
        )
        self.assertEqual(business.effective_plan, Business.PLAN_FREE)

    def test_base_plan_never_downgraded_by_missing_subscription(self):
        owner, business = make_business("licensed@example.com", "Licensed")
        business.plan = Business.PLAN_PREMIUM
        business.save(update_fields=["plan"])
        self.assertEqual(business.effective_plan, Business.PLAN_PREMIUM)

    def test_shorter_higher_tier_subscription_still_wins(self):
        """Regression test: a longer-running Premium subscription coexisting
        with a shorter but higher-tier PremiumPlus one must not make
        effective_plan (or active_referral_subscription) report only
        Premium just because it expires later."""
        owner, business = make_business("tiebreak@example.com", "Tiebreak")
        today = timezone.localdate()
        Subscription.objects.create(
            business=business, user=owner, plan=Business.PLAN_PREMIUM, status=Subscription.STATUS_ACTIVE,
            start_date=today, end_date=today + timedelta(days=90), source=Coupon.SOURCE_ADMIN,
        )
        Subscription.objects.create(
            business=business, user=owner, plan=Business.PLAN_PREMIUMPLUS, status=Subscription.STATUS_ACTIVE,
            start_date=today, end_date=today + timedelta(days=10), source=Coupon.SOURCE_ADMIN,
        )
        self.assertEqual(business.effective_plan, Business.PLAN_PREMIUMPLUS)
        self.assertEqual(business.active_referral_subscription.plan, Business.PLAN_PREMIUMPLUS)


@override_settings(ALLOWED_HOSTS=["testserver"])
class BillingApiTests(TestCase):
    """Round-trips through the real HTTP views — catches bugs the
    service-level tests above can't see, like request.data handing back
    plain strings where the service layer expects real date objects."""

    def setUp(self):
        self.referrer_owner, self.referrer_business = make_business("apiref@example.com", "ApiReferrer")
        self.new_owner, self.new_business = make_business("apinew@example.com", "ApiNew")
        self.admin = User.objects.create(email="apiadmin@example.com", name="Admin", is_platform_admin=True)

        self.referrer_client = APIClient()
        self.referrer_client.force_authenticate(user=self.referrer_owner)
        self.referrer_headers = {"HTTP_X_BUSINESS_ID": str(self.referrer_business.id)}

        self.new_client = APIClient()
        self.new_client.force_authenticate(user=self.new_owner)
        self.new_headers = {"HTTP_X_BUSINESS_ID": str(self.new_business.id)}

        self.admin_client = APIClient()
        self.admin_client.force_authenticate(user=self.admin)

    def test_create_coupon_via_api_with_string_dates(self):
        """Regression test for the bug caught during manual smoke testing:
        end_date arrives as a plain string in request.data and must be
        parsed before Coupon.computed_status compares it against a real
        date — this used to 500."""
        r = self.admin_client.post(
            "/api/superadmin/coupons/",
            {"user": self.new_owner.id, "plan": Business.PLAN_PREMIUMPLUS, "end_date": "2026-12-01"},
            format="json",
        )
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(r.data["status"], "ACTIVE")
        self.assertEqual(r.data["plan"], Business.PLAN_PREMIUMPLUS)

    def test_apply_coupon_end_to_end(self):
        r = self.admin_client.post(
            "/api/superadmin/coupons/",
            {"user": self.new_owner.id, "plan": Business.PLAN_PREMIUM, "end_date": "2026-12-01"},
            format="json",
        )
        code = r.data["code"]

        r = self.new_client.post("/api/billing/apply-coupon/", {"code": code}, format="json", **self.new_headers)
        self.assertEqual(r.status_code, 200, r.content)

        r = self.new_client.get("/api/billing/subscription/", **self.new_headers)
        self.assertEqual(r.data["effective_plan"], Business.PLAN_PREMIUM)

        # Someone else's account can't reuse it.
        r = self.referrer_client.post("/api/billing/apply-coupon/", {"code": code}, format="json", **self.referrer_headers)
        self.assertEqual(r.status_code, 400)

    def test_create_business_with_referral_code_rewards_both_sides(self):
        r = self.referrer_client.get("/api/billing/referral/", **self.referrer_headers)
        code = r.data["referral_code"]

        r = self.new_client.post(
            "/api/auth/businesses/",
            {"name": "Referred via API", "referral_code": code},
            format="json",
        )
        self.assertEqual(r.status_code, 201, r.content)
        new_business_id = r.data["id"]

        r = self.new_client.get("/api/billing/subscription/", HTTP_X_BUSINESS_ID=str(new_business_id))
        self.assertEqual(r.data["effective_plan"], Business.PLAN_PREMIUM)

        r = self.referrer_client.get("/api/billing/subscription/", **self.referrer_headers)
        self.assertEqual(r.data["effective_plan"], Business.PLAN_PREMIUM)

    def test_coupon_deactivate_via_api(self):
        r = self.admin_client.post(
            "/api/superadmin/coupons/",
            {"user": self.new_owner.id, "plan": Business.PLAN_PREMIUM, "end_date": "2026-12-01"},
            format="json",
        )
        coupon_id = r.data["id"]
        r = self.admin_client.post(f"/api/superadmin/coupons/{coupon_id}/deactivate/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["status"], "CANCELLED")

    def test_referral_stats_api(self):
        r = self.referrer_client.get("/api/billing/referral/", **self.referrer_headers)
        code = r.data["referral_code"]
        self.new_client.post("/api/auth/businesses/", {"name": "Stats Test", "referral_code": code}, format="json")

        r = self.admin_client.get("/api/superadmin/referrals/stats/")
        self.assertEqual(r.status_code, 200)
        self.assertGreaterEqual(r.data["rewarded"], 1)


class NinetyDayTrialThenReferralTests(TestCase):
    """90 days free; after that a referral's month of Premium keeps the business going."""

    def setUp(self):
        # Businesses older than LICENSING_STARTS are exempt from the trial, and
        # these ones are back-dated — so move that line out of the way.
        patcher = mock.patch.object(Business, "LICENSING_STARTS", date(2000, 1, 1))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.referrer = make_business("ref@example.com", "Referrer")[1]
        self.newcomer = make_business("new@example.com", "Newcomer")[1]

    def age(self, business, days):
        Business.objects.filter(pk=business.pk).update(created_at=timezone.now() - timedelta(days=days))
        business.refresh_from_db()

    def test_the_free_period_is_ninety_days(self):
        self.assertEqual(Business.TRIAL_DAYS, 90)
        self.age(self.newcomer, 89)
        self.assertTrue(self.newcomer.is_trial_active)
        self.age(self.newcomer, 91)
        self.assertFalse(self.newcomer.is_trial_active)

    def test_after_the_trial_a_referral_adds_a_month_of_premium_and_access(self):
        self.age(self.newcomer, 100)                      # trial over
        self.assertFalse(self.newcomer.has_active_subscription)
        process_referral(new_business=self.newcomer, referrer_business=self.referrer)
        self.newcomer.refresh_from_db()
        self.assertTrue(self.newcomer.has_active_subscription)
        self.assertEqual(self.newcomer.effective_plan, Business.PLAN_PREMIUM)
        sub = self.newcomer.active_referral_subscription
        self.assertEqual((sub.end_date - timezone.localdate()).days, 30)


class ReferralLinkTests(TestCase):
    def test_the_shared_link_points_at_the_website_not_the_backend(self):
        from django.conf import settings

        user, business = make_business("linker@example.com", "Linker")
        api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        api.force_authenticate(user)
        data = api.get("/api/billing/referral/").data
        self.assertEqual(data["referral_link"], f"{settings.FRONTEND_URL}/r/{business.referral_code}")
        self.assertNotIn("onrender.com", data["referral_link"])
        self.assertTrue(data["referral_link"].startswith("https://"))
