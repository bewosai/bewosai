from datetime import timedelta

from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import ACCOUNT_BUSINESS, LoginActivity, OTPCode, User


def bearer(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


class LastActiveTrackingTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(email="u@example.com", name="U")

    def test_an_authenticated_request_records_last_active(self):
        self.assertIsNone(User.objects.get(pk=self.user.pk).last_active_at)
        bearer(self.user).get("/api/auth/me/")
        self.assertIsNotNone(User.objects.get(pk=self.user.pk).last_active_at)

    def test_it_is_not_rewritten_on_every_request(self):
        client = bearer(self.user)
        client.get("/api/auth/me/")
        first = User.objects.get(pk=self.user.pk).last_active_at
        client.get("/api/auth/me/")
        self.assertEqual(User.objects.get(pk=self.user.pk).last_active_at, first)

    def test_it_is_refreshed_once_it_is_stale(self):
        User.objects.filter(pk=self.user.pk).update(last_active_at=timezone.now() - timedelta(minutes=30))
        stale = User.objects.get(pk=self.user.pk).last_active_at
        bearer(self.user).get("/api/auth/me/")
        self.assertGreater(User.objects.get(pk=self.user.pk).last_active_at, stale)

    def test_a_request_without_a_valid_token_records_nothing(self):
        APIClient().get("/api/auth/me/")
        self.assertIsNone(User.objects.get(pk=self.user.pk).last_active_at)


class AdminUsersListTests(TestCase):
    def setUp(self):
        cache.clear()
        self.admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        self.client = bearer(self.admin)

    def sign_in(self, email, ua="Mozilla/5.0 (Linux; Android 14) Chrome"):
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        res = APIClient(HTTP_USER_AGENT=ua).post("/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        return User.objects.get(email=email)

    def rows(self, **params):
        res = self.client.get("/api/superadmin/users/", params)
        self.assertEqual(res.status_code, 200, res.content)
        return res.data["results"]

    def test_only_platform_admins_can_list_users(self):
        normal = User.objects.create_user(email="n@example.com", name="N")
        self.assertEqual(bearer(normal).get("/api/superadmin/users/").status_code, 403)

    def test_each_user_shows_login_data(self):
        self.sign_in("ram@example.com")
        self.sign_in("ram@example.com")            # twice
        row = next(r for r in self.rows() if r["email"] == "ram@example.com")
        self.assertEqual(row["login_count"], 2)
        self.assertIsNotNone(row["last_login_at"])
        self.assertIn("Android", row["last_login_device"])
        self.assertIn("last_active_at", row)

    def test_a_user_who_never_signed_in_has_empty_login_data_not_an_error(self):
        User.objects.create_user(email="new@example.com", name="New")
        row = next(r for r in self.rows() if r["email"] == "new@example.com")
        self.assertEqual(row["login_count"], 0)
        self.assertIsNone(row["last_login_at"])
        self.assertIsNone(row["last_login_device"])
        self.assertFalse(row["is_online"])

    def test_failed_sign_ins_are_not_counted(self):
        user = self.sign_in("ram@example.com")
        LoginActivity.objects.create(user=user, success=False)
        row = next(r for r in self.rows() if r["email"] == "ram@example.com")
        self.assertEqual(row["login_count"], 1)

    def test_online_means_active_in_the_last_ten_minutes(self):
        online = User.objects.create_user(email="on@example.com", name="On")
        away = User.objects.create_user(email="off@example.com", name="Off")
        User.objects.filter(pk=online.pk).update(last_active_at=timezone.now() - timedelta(minutes=3))
        User.objects.filter(pk=away.pk).update(last_active_at=timezone.now() - timedelta(hours=2))
        by_email = {r["email"]: r for r in self.rows()}
        self.assertTrue(by_email["on@example.com"]["is_online"])
        self.assertFalse(by_email["off@example.com"]["is_online"])

    def test_sort_by_most_recently_active_puts_never_active_users_last(self):
        a = User.objects.create_user(email="a@example.com", name="A")
        b = User.objects.create_user(email="b@example.com", name="B")
        User.objects.create_user(email="never@example.com", name="Never")
        User.objects.filter(pk=a.pk).update(last_active_at=timezone.now() - timedelta(hours=5))
        User.objects.filter(pk=b.pk).update(last_active_at=timezone.now() - timedelta(minutes=1))
        emails = [r["email"] for r in self.rows(ordering="active")]
        self.assertLess(emails.index("b@example.com"), emails.index("a@example.com"))
        self.assertLess(emails.index("a@example.com"), emails.index("never@example.com"))

    def test_sort_by_most_logins(self):
        busy = self.sign_in("busy@example.com")
        for _ in range(2):
            self.sign_in("busy@example.com")
        self.sign_in("quiet@example.com")
        emails = [r["email"] for r in self.rows(ordering="logins")]
        self.assertLess(emails.index("busy@example.com"), emails.index("quiet@example.com"))

    def test_an_unknown_ordering_is_ignored_not_an_error(self):
        self.assertEqual(self.client.get("/api/superadmin/users/", {"ordering": "password; drop"}).status_code, 200)

    def test_search_still_works_and_matches_name_email_or_phone(self):
        User.objects.create_user(email="find.me@example.com", name="Sita Sharma")
        User.objects.create_user(email="other@example.com", name="Other")
        self.assertEqual([r["email"] for r in self.rows(search="sharma")], ["find.me@example.com"])
        self.assertEqual([r["email"] for r in self.rows(search="find.me")], ["find.me@example.com"])
