"""
"Everyone who signs in, from the app or the website, shows up in Super Admin."
That's not one code path — it's a guarantee that has to hold across every way
someone actually authenticates. One test per path, plus platform (app vs web,
via the X-Platform header) and a check that nothing here is filtered by it.
"""
from unittest import mock

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import ACCOUNT_BUSINESS, Business, OTPCode, StaffMember, User


class EveryoneWhoSignsInShowsUpTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        self.admin_client = APIClient()
        self.admin_client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {self._token(self.admin)}"
        )

    @staticmethod
    def _token(user):
        from rest_framework_simplejwt.tokens import RefreshToken
        return str(RefreshToken.for_user(user).access_token)

    def admin_sees(self, email):
        res = self.admin_client.get("/api/superadmin/users/", {"search": email})
        self.assertEqual(res.status_code, 200, res.content)
        rows = res.data.get("results", res.data)
        return next((r for r in rows if r["email"] == email), None)

    # ── every real sign-in path lands a User + LoginActivity Super Admin can see ──

    def test_email_code_sign_in_from_the_app(self):
        email = "app.user@example.com"
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        res = APIClient(HTTP_X_PLATFORM="mobile", HTTP_USER_AGENT="Dart/3 (dart:io)").post(
            "/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json",
        )
        self.assertEqual(res.status_code, 200, res.content)
        row = self.admin_sees(email)
        self.assertIsNotNone(row, "app sign-in did not appear in Super Admin's Users list")
        self.assertEqual(row["login_count"], 1)
        self.assertIsNotNone(row["last_login_at"])

    def test_email_code_sign_in_from_the_website(self):
        email = "web.user@example.com"
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        res = APIClient(HTTP_X_PLATFORM="web", HTTP_USER_AGENT="Mozilla/5.0 Chrome").post(
            "/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json",
        )
        self.assertEqual(res.status_code, 200, res.content)
        row = self.admin_sees(email)
        self.assertIsNotNone(row, "website sign-in did not appear in Super Admin's Users list")
        self.assertEqual(row["login_count"], 1)

    def test_google_sign_in(self):
        email = "google.user@example.com"
        fake_payload = {"email": email, "email_verified": True, "name": "Google User"}
        with mock.patch("accounts.views.google_id_token.verify_oauth2_token", return_value=fake_payload), \
             override_settings(GOOGLE_OAUTH_CLIENT_ID="fake-client-id"):
            res = APIClient().post("/api/auth/google-login/", {"id_token": "fake"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        row = self.admin_sees(email)
        self.assertIsNotNone(row, "Google sign-in did not appear in Super Admin's Users list")
        self.assertEqual(row["login_count"], 1)

    def test_staff_login_link_from_the_app(self):
        owner = User.objects.create_user(email="owner@example.com", name="Owner")
        business = Business.objects.create(owner=owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=owner, business=business, role=StaffMember.ROLE_OWNER)
        staff_client = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        staff_client.credentials(HTTP_AUTHORIZATION=f"Bearer {self._token(owner)}")
        invited = staff_client.post(
            f"/api/auth/businesses/{business.id}/staff/",
            {"name": "Sita", "role": "CASHIER", "permissions": {}}, format="json",
        )
        self.assertEqual(invited.status_code, 201, invited.content)

        res = APIClient(HTTP_X_PLATFORM="mobile").post(
            "/api/auth/staff-login/", {"token": invited.data["login_token"]}, format="json",
        )
        self.assertEqual(res.status_code, 200, res.content)

        # A link-only staff member has no email/phone — found by name, not search
        # (search only matches email/name/phone, and name does match here).
        rows = self.admin_client.get("/api/superadmin/users/", {"search": "Sita"}).data["results"]
        row = next((r for r in rows if r["id"] == invited.data["user"]), None)
        self.assertIsNotNone(row, "staff login-link sign-in did not appear in Super Admin's Users list")
        self.assertEqual(row["login_count"], 1)

    # ── the list itself is never filtered by platform ──

    def test_the_users_list_has_no_platform_filter_at_all(self):
        import inspect
        from superadmin.views import UserManagementView
        source = inspect.getsource(UserManagementView.get)
        self.assertNotIn("platform", source.lower(), "UserManagementView.get must not filter by X-Platform")

    def test_app_and_web_accounts_both_appear_in_the_same_unfiltered_list(self):
        app_email, web_email = "onlyapp@example.com", "onlyweb@example.com"
        for email, platform in [(app_email, "mobile"), (web_email, "web")]:
            _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
            APIClient(HTTP_X_PLATFORM=platform).post(
                "/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json",
            )
        all_rows = self.admin_client.get("/api/superadmin/users/", {"page_size": 1000}).data["results"]
        emails = {r["email"] for r in all_rows}
        self.assertIn(app_email, emails)
        self.assertIn(web_email, emails)

    def test_a_non_admin_cannot_see_the_list_at_all(self):
        normal = User.objects.create_user(email="normal@example.com", name="Normal")
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {self._token(normal)}")
        self.assertEqual(client.get("/api/superadmin/users/").status_code, 403)


class LoginDataIsSavedCorrectlyTests(TestCase):
    """Behind Render's proxy REMOTE_ADDR is the proxy, not the person."""

    def sign_in(self, email, **headers):
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        res = APIClient(**headers).post("/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        return User.objects.get(email=email)

    def test_login_saves_time_device_and_the_real_client_ip(self):
        user = self.sign_in(
            "ip@example.com", HTTP_X_FORWARDED_FOR="203.0.113.7, 10.0.0.1",
            REMOTE_ADDR="10.0.0.1", HTTP_USER_AGENT="Dart/3.4 (dart:io)",
        )
        self.assertIsNotNone(user.last_login_at)
        entry = user.login_activities.get()
        self.assertEqual(entry.ip_address, "203.0.113.7")
        self.assertEqual(entry.user_agent, "Dart/3.4 (dart:io)")

    def test_a_garbage_forwarded_header_falls_back_instead_of_crashing_the_login(self):
        user = self.sign_in("bad@example.com", HTTP_X_FORWARDED_FOR="not-an-ip", REMOTE_ADDR="198.51.100.4")
        self.assertEqual(user.login_activities.get().ip_address, "198.51.100.4")

    def test_every_login_adds_an_entry_and_moves_last_login_forward(self):
        first = self.sign_in("twice@example.com").last_login_at
        second = self.sign_in("twice@example.com")
        self.assertEqual(second.login_activities.count(), 2)
        self.assertGreaterEqual(second.last_login_at, first)


class InvoiceReachesSuperAdminTests(TestCase):
    """An invoice saved through the same API the app and website both call
    shows up in Super Admin's per-user totals and activity."""

    def test_an_invoice_created_from_the_app_is_counted_and_logged(self):
        from decimal import Decimal
        from inventory.models import Product

        owner = User.objects.create_user(email="shop@example.com", name="Shop Owner", is_verified=True)
        business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=business, role=StaffMember.ROLE_OWNER)
        product = Product.objects.create(
            business=business, name="Rice", sale_price=Decimal("100"), purchase_price=Decimal("60"), stock_quantity=Decimal("10"),
        )
        api = APIClient(HTTP_X_BUSINESS_ID=str(business.id), HTTP_X_PLATFORM="mobile")
        api.force_authenticate(owner)
        res = api.post("/api/sales/", {
            "invoice_number": "INV-1", "sale_date": "2026-09-19", "payment_method": "CASH", "paid_amount": "200",
            "items": [{"product": product.id, "product_name": "Rice", "quantity": "2", "unit_price": "100"}],
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)

        admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        admin_api = APIClient()
        admin_api.force_authenticate(admin)
        summary = admin_api.get(f"/api/superadmin/users/{owner.id}/summary/")
        self.assertEqual(summary.data["total_sales"], 1)
        activity = admin_api.get(f"/api/superadmin/users/{owner.id}/activity/").data["results"]
        self.assertTrue(any(a["object_repr"] == "Invoice INV-1" for a in activity), activity)


class PlatformStatsShowEverythingTests(TestCase):
    def test_overview_counts_saved_data_and_splits_app_from_website_logins(self):
        from accounts.models import LoginActivity
        from parties.models import Party

        owner = User.objects.create_user(email="o@example.com", name="O")
        business = Business.objects.create(owner=owner, name="Shop")
        Party.objects.create(business=business, name="Ram")
        LoginActivity.objects.create(user=owner, user_agent="Dart/3.4 (dart:io)")
        LoginActivity.objects.create(user=owner, user_agent="Mozilla/5.0 Chrome/120")
        LoginActivity.objects.create(user=owner, user_agent="Mozilla/5.0 Chrome/120")

        admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        api = APIClient()
        api.force_authenticate(admin)
        data = api.get("/api/superadmin/stats/").data
        self.assertEqual((data["app_logins_last_30_days"], data["web_logins_last_30_days"]), (1, 2))
        self.assertEqual(data["total_parties"], 1)
        for key in ("total_sales", "total_purchases", "total_expenses", "total_products"):
            self.assertEqual(data[key], 0, key)
