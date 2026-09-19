from io import StringIO

from django.core.cache import cache
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import OTPCode, User, ACCOUNT_BUSINESS


class _ClearThrottleCache(TestCase):
    def setUp(self):
        super().setUp()
        cache.clear()

    def tearDown(self):
        cache.clear()
        super().tearDown()


class PlatformAdminAllowListTests(_ClearThrottleCache):
    def sign_in_with_code(self, email):
        _, code = OTPCode.generate(email.lower(), ACCOUNT_BUSINESS)  # send-otp lowercases the address
        return APIClient().post("/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json")

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_a_listed_email_becomes_platform_admin_when_it_signs_in(self):
        res = self.sign_in_with_code("boss@example.com")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertTrue(res.data["user"]["is_platform_admin"])
        self.assertTrue(User.objects.get(email="boss@example.com").is_platform_admin)

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_the_match_ignores_case(self):
        res = self.sign_in_with_code("Boss@Example.com")
        self.assertTrue(res.data["user"]["is_platform_admin"])

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_an_unlisted_email_never_becomes_admin(self):
        res = self.sign_in_with_code("someone@example.com")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["user"]["is_platform_admin"])

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_a_wrong_code_does_not_grant_anything(self):
        OTPCode.generate("boss@example.com", ACCOUNT_BUSINESS)
        res = APIClient().post("/api/auth/verify-otp/", {"identifier": "boss@example.com", "code": "000000"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(User.objects.filter(email="boss@example.com", is_platform_admin=True).exists())

    def test_with_no_list_configured_nobody_is_granted_admin(self):
        res = self.sign_in_with_code("boss@example.com")
        self.assertFalse(res.data["user"]["is_platform_admin"])

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_a_platform_admin_can_reach_the_super_admin_api_after_signing_in(self):
        res = self.sign_in_with_code("boss@example.com")
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        self.assertEqual(client.get("/api/superadmin/stats/").status_code, 200)


class MakePlatformAdminCommandTests(TestCase):
    def run_cmd(self, *args):
        out = StringIO()
        call_command("make_platform_admin", *args, stdout=out)
        return out.getvalue()

    def test_promotes_an_existing_account(self):
        User.objects.create_user(email="a@example.com", name="A")
        self.assertIn("now a platform admin", self.run_cmd("a@example.com"))
        self.assertTrue(User.objects.get(email="a@example.com").is_platform_admin)

    def test_creates_the_account_when_it_does_not_exist_yet(self):
        self.assertIn("new account created", self.run_cmd("New@Example.com"))
        user = User.objects.get(email="new@example.com")
        self.assertTrue(user.is_platform_admin and user.is_verified)

    def test_revoke(self):
        self.run_cmd("a@example.com")
        self.assertIn("no longer", self.run_cmd("a@example.com", "--revoke"))
        self.assertFalse(User.objects.get(email="a@example.com").is_platform_admin)

    def test_rejects_something_that_is_not_an_email(self):
        with self.assertRaises(CommandError):
            self.run_cmd("not-an-email")


class OtpThrottlingTests(_ClearThrottleCache):
    def send(self, email="x@example.com"):
        return APIClient().post("/api/auth/send-otp/", {"identifier": email}, format="json")

    def test_more_than_the_old_five_an_hour_limit_can_be_sent_from_one_address(self):
        # 7 different people behind one IP (a phone network, a shop's WiFi) used to
        # hit "Request was throttled" after the 5th.
        for n in range(7):
            self.assertEqual(self.send(f"user{n}@example.com").status_code, 200, n)

    def test_one_email_is_capped_per_hour_with_a_plain_message(self):
        for _ in range(OTPCode.MAX_SENDS_PER_HOUR):
            OTPCode.generate("spam@example.com", ACCOUNT_BUSINESS)
        # age the newest one past the 60s resend cooldown so only the hourly cap can refuse
        from datetime import timedelta
        from django.utils import timezone
        OTPCode.objects.filter(identifier="spam@example.com").update(created_at=timezone.now() - timedelta(minutes=2))
        res = self.send("spam@example.com")
        self.assertEqual(res.status_code, 429)
        self.assertIn("Too many codes", res.data["message"])

    def test_when_the_ip_limit_is_hit_the_message_is_plain_not_technical(self):
        from unittest import mock
        from rest_framework.throttling import ScopedRateThrottle

        with mock.patch.object(ScopedRateThrottle, "THROTTLE_RATES", {"otp_send": "2/hour", "otp_verify": "2/hour"}):
            self.send("a@example.com")
            self.send("b@example.com")
            res = self.send("c@example.com")
        self.assertEqual(res.status_code, 429)
        self.assertNotIn("Request was throttled", res.data["message"])
        self.assertIn("try again in", res.data["message"])


class AlreadySignedInTests(_ClearThrottleCache):
    """Added to PLATFORM_ADMIN_EMAILS while already signed in: admin on the next request."""

    def bearer(self, user):
        from rest_framework_simplejwt.tokens import RefreshToken
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
        return client

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_a_signed_in_verified_account_becomes_admin_on_its_next_request(self):
        user = User.objects.create_user(email="boss@example.com", name="Boss", is_verified=True)
        self.assertFalse(user.is_platform_admin)
        res = self.bearer(user).get("/api/superadmin/stats/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertTrue(User.objects.get(pk=user.pk).is_platform_admin)

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_an_unverified_account_is_not_granted_this_way(self):
        user = User.objects.create_user(email="boss@example.com", name="Boss", is_verified=False)
        self.assertEqual(self.bearer(user).get("/api/superadmin/stats/").status_code, 403)
        self.assertFalse(User.objects.get(pk=user.pk).is_platform_admin)

    @override_settings(PLATFORM_ADMIN_EMAILS=["boss@example.com"])
    def test_an_unlisted_account_is_never_granted(self):
        user = User.objects.create_user(email="other@example.com", name="Other", is_verified=True)
        self.assertEqual(self.bearer(user).get("/api/superadmin/stats/").status_code, 403)
