from django.core.cache import cache
from django.db import connection
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from superadmin.models import BusinessFeatureOverride, Feature


@override_settings(FEATURE_CACHE_SECONDS=30)
class FeatureCacheTests(TestCase):
    def setUp(self):
        cache.clear()
        self.addCleanup(cache.clear)
        owner = User.objects.create_user(email="o@example.com", name="O")
        self.business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient()
        self.api.force_authenticate(owner)
        self.h = {"HTTP_X_BUSINESS_ID": str(self.business.id)}

    def get_parties(self):
        return self.api.get("/api/parties/", **self.h)

    def test_repeat_requests_skip_the_feature_lookups(self):
        self.get_parties()
        with CaptureQueriesContext(connection) as queries:
            self.assertEqual(self.get_parties().status_code, 200)
        tables = " ".join(q["sql"] for q in queries.captured_queries)
        self.assertNotIn("superadmin_feature", tables)
        self.assertNotIn("superadmin_businessfeatureoverride", tables)

    def test_switching_a_feature_off_applies_immediately(self):
        self.assertEqual(self.get_parties().status_code, 200)
        feature = Feature.objects.get(key="parties")
        feature.enabled = False
        feature.save()
        self.assertEqual(self.get_parties().status_code, 403)

    def test_a_business_override_applies_immediately_and_so_does_removing_it(self):
        Feature.objects.filter(key="parties").update(enabled=False)  # platform-wide off …
        cache.clear()
        self.assertEqual(self.get_parties().status_code, 403)
        override = BusinessFeatureOverride.objects.create(
            business=self.business, feature_key="parties", enabled=True,
        )
        self.assertEqual(self.get_parties().status_code, 200)  # … but granted to this business
        override.delete()
        self.assertEqual(self.get_parties().status_code, 403)
