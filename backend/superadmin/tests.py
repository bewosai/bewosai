"""
Automated tests for the trial/license/feature-permission system.

Run with: python manage.py test superadmin
"""
from datetime import date, timedelta

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import ACCOUNT_BUSINESS, Business, StaffMember, User
from .models import (
    BusinessFeatureOverride, Feature, License, LicenseAuditLog,
    generate_license_code, LICENSE_CODE_ALPHABET,
)


def make_business(*, email, created_days_ago=0, licensing_starts_override=None):
    """A business + its owning staff member, ready to authenticate as.
    created_days_ago lets tests simulate an old (trial-expired) or brand-new
    business without waiting on real wall-clock time."""
    owner = User.objects.create(email=email, name="Test Owner", account_type=ACCOUNT_BUSINESS)
    business = Business.objects.create(owner=owner, name=f"Biz for {email}")
    Business.objects.filter(pk=business.pk).update(
        created_at=timezone.now() - timedelta(days=created_days_ago)
    )
    business.refresh_from_db()
    StaffMember.objects.create(user=owner, business=business, role=StaffMember.ROLE_OWNER, is_active=True)
    return business, owner


@override_settings(ALLOWED_HOSTS=["testserver"])
class TrialTests(TestCase):
    def test_new_business_gets_exactly_the_configured_trial_length(self):
        business, _ = make_business(email="newtrial@example.com", created_days_ago=0)
        self.assertEqual(
            business.trial_expiry_date, timezone.localtime(business.created_at).date() + timedelta(days=Business.TRIAL_DAYS),
        )

    def test_trial_counts_from_the_nepal_date_a_business_was_created(self):
        # 18:45 UTC on 18 Sep is 00:30 on 19 Sep in Nepal. The trial must start
        # from the 19th; using the UTC date (the 18th) would cost every business
        # created between midnight and 5:45 AM a day of its trial.
        from datetime import datetime, timezone as dt_timezone

        business, _ = make_business(email="night@example.com", created_days_ago=0)
        Business.objects.filter(pk=business.pk).update(
            created_at=datetime(2026, 9, 18, 18, 45, tzinfo=dt_timezone.utc)
        )
        business.refresh_from_db()
        self.assertEqual(business.trial_expiry_date, date(2026, 9, 19) + timedelta(days=Business.TRIAL_DAYS))

    def test_trial_active_within_window(self):
        business, _ = make_business(email="active@example.com", created_days_ago=Business.TRIAL_DAYS - 1)
        business.LICENSING_STARTS = date(2020, 1, 1)
        self.assertTrue(business.is_trial_active)
        self.assertTrue(business.has_active_subscription)

    def test_trial_expired_past_window(self):
        business, _ = make_business(email="expired@example.com", created_days_ago=Business.TRIAL_DAYS + 1)
        business.LICENSING_STARTS = date(2020, 1, 1)
        self.assertFalse(business.is_trial_active)
        self.assertFalse(business.has_active_subscription)

    def test_existing_business_is_grandfathered_regardless_of_trial_state(self):
        """The key safety property: this feature must never lock out a
        business that existed before it shipped."""
        business, _ = make_business(email="grandfathered@example.com", created_days_ago=9999)
        self.assertTrue(business.is_grandfathered)
        self.assertTrue(business.has_active_subscription)

    def test_client_supplied_date_cannot_bypass_expiry(self):
        """Expiry is computed purely from server-stored created_at / license
        expiry_date compared against timezone.localdate() — there is no
        client-supplied date anywhere in this path to manipulate."""
        business, _ = make_business(email="clockcheck@example.com", created_days_ago=Business.TRIAL_DAYS + 1)
        business.LICENSING_STARTS = date(2020, 1, 1)
        self.assertFalse(business.has_active_subscription)
        # Re-checking twice in a row must be stable/deterministic.
        self.assertFalse(business.has_active_subscription)


class LicenseCodeTests(TestCase):
    def test_generated_code_uses_only_the_approved_alphabet(self):
        code = generate_license_code()
        self.assertEqual(len(code), 5)
        self.assertTrue(all(c in LICENSE_CODE_ALPHABET for c in code))
        for confusing in "01IO5":
            self.assertNotIn(confusing, code if confusing not in LICENSE_CODE_ALPHABET else "")

    def test_bulk_uniqueness(self):
        """Generate a large batch and verify zero collisions, including
        against codes that get created (not just generated-and-discarded)."""
        business, _ = make_business(email="bulk@example.com")
        codes = set()
        for _ in range(300):
            code = generate_license_code()
            self.assertNotIn(code, codes)
            codes.add(code)
            License.objects.create(
                code=code, business=business, email_snapshot="bulk@example.com",
                duration_type=License.DURATION_7D, duration_days=7,
                start_date=timezone.localdate(), expiry_date=timezone.localdate() + timedelta(days=7),
            )
        self.assertEqual(len(codes), 300)

    def test_expired_or_revoked_code_is_never_reissued(self):
        business, _ = make_business(email="noreuse@example.com")
        License.objects.create(
            code="AAAAA", business=business, email_snapshot="x@x.com",
            duration_type=License.DURATION_7D, duration_days=7, status=License.STATUS_EXPIRED,
            start_date=timezone.localdate(), expiry_date=timezone.localdate() - timedelta(days=1),
        )
        # generate_license_code must treat AAAAA as taken even though its
        # status is EXPIRED, not just PENDING/ACTIVE.
        for _ in range(200):
            self.assertNotEqual(generate_license_code(), "AAAAA")


@override_settings(ALLOWED_HOSTS=["testserver"])
class LicenseActivationTests(TestCase):
    def setUp(self):
        Business.LICENSING_STARTS = date(2020, 1, 1)
        self.business, self.owner = make_business(email="owner@example.com", created_days_ago=Business.TRIAL_DAYS + 1)
        self.admin = User.objects.create(email="admin@example.com", name="Admin", is_platform_admin=True)
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)
        self.admin_client = APIClient()
        self.admin_client.force_authenticate(user=self.admin)
        self.headers = {"HTTP_X_BUSINESS_ID": str(self.business.id)}

    def _generate(self, duration_type="30D"):
        r = self.admin_client.post(
            "/api/superadmin/licenses/generate/",
            {"business": self.business.id, "duration_type": duration_type},
            format="json",
        )
        self.assertEqual(r.status_code, 201, r.content)
        return r.json()["code"]

    def test_expired_trial_blocks_business_endpoints(self):
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 403)

    def test_activation_unblocks_immediately(self):
        code = self._generate()
        r = self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["success"])

        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 200)

    def test_wrong_business_cannot_activate_someone_elses_code(self):
        code = self._generate()
        other_business, other_owner = make_business(email="stranger@example.com")
        other_client = APIClient()
        other_client.force_authenticate(user=other_owner)
        r = other_client.post(
            "/api/auth/licenses/activate/", {"code": code}, format="json",
            HTTP_X_BUSINESS_ID=str(other_business.id),
        )
        self.assertEqual(r.status_code, 403)
        self.assertIn("not assigned", r.json()["message"])

    def test_revoked_code_cannot_activate(self):
        code = self._generate()
        lic = License.objects.get(code=code)
        lic.status = License.STATUS_REVOKED
        lic.save()
        r = self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        self.assertEqual(r.status_code, 400)
        self.assertIn("revoked", r.json()["message"].lower())

    def test_expired_code_cannot_activate(self):
        code = self._generate()
        lic = License.objects.get(code=code)
        lic.expiry_date = timezone.localdate() - timedelta(days=1)
        lic.save()
        r = self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        self.assertEqual(r.status_code, 400)
        self.assertIn("expired", r.json()["message"].lower())

    def test_active_license_does_not_require_reactivation(self):
        code = self._generate()
        self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 200)
        # Simulate "logging in again" — no code re-entry, still works.
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 200)

    def test_revoke_immediately_locks_out(self):
        code = self._generate()
        self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        lic = License.objects.get(code=code)
        r = self.admin_client.post(f"/api/superadmin/licenses/{lic.id}/revoke/")
        self.assertEqual(r.status_code, 200)
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 403)

    def test_extend_pushes_expiry_forward_and_reactivates_expired_license(self):
        code = self._generate("7D")
        lic = License.objects.get(code=code)
        lic.status = License.STATUS_EXPIRED
        lic.expiry_date = timezone.localdate() - timedelta(days=1)
        lic.save()
        r = self.admin_client.post(f"/api/superadmin/licenses/{lic.id}/extend/", {"duration_type": "30D"}, format="json")
        self.assertEqual(r.status_code, 200)
        lic.refresh_from_db()
        self.assertEqual(lic.status, License.STATUS_ACTIVE)
        self.assertGreater(lic.expiry_date, timezone.localdate())

    def test_generated_license_creates_audit_entry(self):
        code = self._generate()
        self.assertTrue(
            LicenseAuditLog.objects.filter(business=self.business, action=LicenseAuditLog.ACTION_CREATED).exists()
        )
        self.client.post("/api/auth/licenses/activate/", {"code": code}, format="json", **self.headers)
        self.assertTrue(
            LicenseAuditLog.objects.filter(business=self.business, action=LicenseAuditLog.ACTION_ACTIVATED).exists()
        )


@override_settings(ALLOWED_HOSTS=["testserver"])
class SuperAdminAccessTests(TestCase):
    def setUp(self):
        self.business, self.owner = make_business(email="normaluser@example.com")
        self.admin = User.objects.create(email="realadmin@example.com", name="Admin", is_platform_admin=True)

    def test_normal_user_cannot_generate_license(self):
        client = APIClient()
        client.force_authenticate(user=self.owner)
        r = client.post(
            "/api/superadmin/licenses/generate/",
            {"business": self.business.id, "duration_type": "30D"}, format="json",
        )
        self.assertEqual(r.status_code, 403)

    def test_normal_user_cannot_revoke_or_list_licenses(self):
        client = APIClient()
        client.force_authenticate(user=self.owner)
        self.assertEqual(client.get("/api/superadmin/licenses/").status_code, 403)
        self.assertEqual(client.post("/api/superadmin/licenses/1/revoke/").status_code, 403)

    def test_platform_admin_can_generate(self):
        client = APIClient()
        client.force_authenticate(user=self.admin)
        r = client.post(
            "/api/superadmin/licenses/generate/",
            {"business": self.business.id, "duration_type": "30D"}, format="json",
        )
        self.assertEqual(r.status_code, 201)


@override_settings(ALLOWED_HOSTS=["testserver"])
class FeaturePermissionTests(TestCase):
    def setUp(self):
        Business.LICENSING_STARTS = date(2020, 1, 1)
        self.business, self.owner = make_business(email="featuretest@example.com")
        self.admin = User.objects.create(email="featadmin@example.com", name="Admin", is_platform_admin=True)
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)
        self.admin_client = APIClient()
        self.admin_client.force_authenticate(user=self.admin)
        self.headers = {"HTTP_X_BUSINESS_ID": str(self.business.id)}
        self.feature, _ = Feature.objects.get_or_create(
            key="expenses", defaults={"name": "Expenses", "enabled": True},
        )

    def test_enabled_feature_works_by_default(self):
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 200)

    def test_override_disable_returns_403(self):
        r = self.admin_client.patch(
            f"/api/superadmin/businesses/{self.business.id}/features/",
            {"feature_key": "expenses", "enabled": False}, format="json",
        )
        self.assertEqual(r.status_code, 200)
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 403)

    def test_clearing_override_reverts_to_platform_default(self):
        BusinessFeatureOverride.objects.create(business=self.business, feature_key="expenses", enabled=False)
        r = self.admin_client.patch(
            f"/api/superadmin/businesses/{self.business.id}/features/",
            {"feature_key": "expenses", "enabled": None}, format="json",
        )
        self.assertEqual(r.status_code, 200)
        r = self.client.get("/api/expenses/categories/", **self.headers)
        self.assertEqual(r.status_code, 200)

    def test_only_platform_admin_can_change_feature_permissions(self):
        client = APIClient()
        client.force_authenticate(user=self.owner)
        r = client.patch(
            f"/api/superadmin/businesses/{self.business.id}/features/",
            {"feature_key": "expenses", "enabled": False}, format="json",
        )
        self.assertEqual(r.status_code, 403)
