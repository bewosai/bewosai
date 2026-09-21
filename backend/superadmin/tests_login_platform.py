"""
Every sign-in records which client it came from (the app or the website), from
the X-Platform header both frontends send — not guessed from the user agent —
and Super Admin shows it per user and counts it in the Overview.
"""
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import ACCOUNT_BUSINESS, LoginActivity, OTPCode, User


class LoginPlatformTests(TestCase):
    def setUp(self):
        admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        self.admin_client = APIClient()
        self.admin_client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(admin).access_token}"
        )

    def sign_in(self, email, **headers):
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        res = APIClient(**headers).post(
            "/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json",
        )
        self.assertEqual(res.status_code, 200, res.content)

    def users_row(self, email):
        res = self.admin_client.get("/api/superadmin/users/", {"search": email})
        self.assertEqual(res.status_code, 200, res.content)
        return next(r for r in res.data["results"] if r["email"] == email)

    def test_app_sign_in_is_recorded_as_app(self):
        self.sign_in("a@example.com", HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Dart/3 (dart:io)")
        self.assertEqual(LoginActivity.objects.get(user__email="a@example.com").platform, "app")
        self.assertEqual(self.users_row("a@example.com")["last_login_platform"], "app")

    def test_website_sign_in_is_recorded_as_web(self):
        self.sign_in("w@example.com", HTTP_X_PLATFORM="web", HTTP_USER_AGENT="Mozilla/5.0 Chrome/120")
        self.assertEqual(LoginActivity.objects.get(user__email="w@example.com").platform, "web")
        self.assertEqual(self.users_row("w@example.com")["last_login_platform"], "web")

    def test_recorded_platform_beats_the_user_agent(self):
        # The header is authoritative: an app build whose HTTP client stops
        # sending a "Dart" user agent must still count as the app.
        self.sign_in("b@example.com", HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Mozilla/5.0 Chrome/120")
        self.assertEqual(self.users_row("b@example.com")["last_login_platform"], "app")

    def test_login_from_before_platform_was_recorded_falls_back_to_user_agent(self):
        app_user = User.objects.create_user(email="old.app@example.com", name="Old App")
        web_user = User.objects.create_user(email="old.web@example.com", name="Old Web")
        LoginActivity.objects.create(user=app_user, user_agent="Dart/3 (dart:io)")
        LoginActivity.objects.create(user=web_user, user_agent="Mozilla/5.0 Chrome/120")
        self.assertEqual(self.users_row("old.app@example.com")["last_login_platform"], "app")
        self.assertEqual(self.users_row("old.web@example.com")["last_login_platform"], "web")

    def test_user_who_never_signed_in_has_no_platform(self):
        User.objects.create_user(email="never@example.com", name="Never")
        self.assertIsNone(self.users_row("never@example.com")["last_login_platform"])

    def test_overview_splits_logins_by_platform(self):
        self.sign_in("a1@example.com", HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Dart/3 (dart:io)")
        self.sign_in("a2@example.com", HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Mozilla/5.0 Chrome/120")
        self.sign_in("w1@example.com", HTTP_X_PLATFORM="web", HTTP_USER_AGENT="Mozilla/5.0 Chrome/120")
        legacy = User.objects.create_user(email="legacy@example.com", name="Legacy")
        LoginActivity.objects.create(user=legacy, user_agent="okhttp/4.12")

        stats = self.admin_client.get("/api/superadmin/stats/").data
        self.assertEqual(stats["logins_last_30_days"], 4)
        self.assertEqual(stats["app_logins_last_30_days"], 3)
        self.assertEqual(stats["web_logins_last_30_days"], 1)

    def test_login_activity_list_carries_the_platform(self):
        self.sign_in("p@example.com", HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Dart/3 (dart:io)")
        rows = self.admin_client.get("/api/superadmin/login-activity/").data["results"]
        self.assertEqual([r["platform"] for r in rows if r["user"] == "p@example.com"], ["app"])
