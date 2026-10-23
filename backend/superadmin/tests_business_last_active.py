"""Super Admin → Businesses shows when anyone (owner or staff) last used each
business, and can list the most recently used first."""
from datetime import timedelta

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User


@override_settings(SUPERADMIN_EMAIL="admin@example.com")
class BusinessLastActiveTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_user(email="admin@example.com", name="Admin", is_platform_admin=True)
        self.api = APIClient()
        self.api.force_authenticate(self.admin)
        now = timezone.now()

        def shop(name, owner_ago=None, staff_ago=None):
            owner = User.objects.create_user(email=f"{name}@example.com", name=name,
                                             last_active_at=now - owner_ago if owner_ago else None)
            biz = Business.objects.create(owner=owner, name=name)
            StaffMember.objects.create(user=owner, business=biz, role=StaffMember.ROLE_OWNER)
            if staff_ago:
                staff = User.objects.create_user(email=f"{name}.staff@example.com", name="Staff",
                                                 last_active_at=now - staff_ago)
                StaffMember.objects.create(user=staff, business=biz, role=StaffMember.ROLE_CASHIER)
            return biz

        self.old = shop("old", owner_ago=timedelta(days=9))
        self.busy = shop("busy", owner_ago=timedelta(days=3), staff_ago=timedelta(minutes=5))
        self.never = shop("never")

    def rows(self, **params):
        res = self.api.get("/api/superadmin/businesses/", params)
        self.assertEqual(res.status_code, 200, res.content)
        return res.data["results"]

    def test_last_active_is_the_most_recent_of_owner_and_staff(self):
        by_name = {r["name"]: r for r in self.rows()}
        busy = by_name["busy"]["last_active_at"]
        self.assertIsNotNone(busy)
        self.assertLess(timezone.now() - busy, timedelta(minutes=10))    # the cashier, 5 min ago
        self.assertIsNone(by_name["never"]["last_active_at"])

    def test_can_list_most_recently_used_first(self):
        names = [r["name"] for r in self.rows(ordering="active")]
        self.assertEqual(names, ["busy", "old", "never"])
