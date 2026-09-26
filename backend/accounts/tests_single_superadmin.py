"""Only settings.SUPERADMIN_EMAIL may ever be a platform admin, however it's attempted."""
from io import StringIO

from django.core.management import call_command
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.admin_access import grant_platform_admin_if_listed
from accounts.models import User

OWNER = "mahatok008@gmail.com"


@override_settings(SUPERADMIN_EMAIL=OWNER, PLATFORM_ADMIN_EMAILS=[OWNER, "other@example.com"])
class SingleSuperAdminTests(TestCase):
    def test_the_owner_email_can_be_superadmin_and_reach_the_panel(self):
        owner = User.objects.create_superuser(email="MahatoK008@Gmail.com")
        self.assertTrue(owner.is_platform_admin)
        api = APIClient()
        api.force_authenticate(owner)
        self.assertEqual(api.get("/api/superadmin/stats/").status_code, 200)
        self.assertTrue(api.get("/api/auth/me/").data["is_platform_admin"])

    def test_no_other_account_can_be_made_superadmin(self):
        via_create = User.objects.create_user(email="a@example.com", is_platform_admin=True)
        via_superuser = User.objects.create_superuser(email="b@example.com")
        via_allow_list = User.objects.create_user(email="other@example.com", is_verified=True)
        grant_platform_admin_if_listed(via_allow_list)
        via_update = User.objects.create_user(email="c@example.com")
        via_update.is_platform_admin = True
        via_update.save(update_fields=["name"])
        call_command("make_platform_admin", "d@example.com", stdout=StringIO())

        for email in ("a@example.com", "b@example.com", "other@example.com", "c@example.com", "d@example.com"):
            self.assertFalse(User.objects.get(email=email).is_platform_admin, email)

    def test_an_old_row_with_the_flag_already_set_is_still_refused(self):
        User.objects.create_user(email="old@example.com")
        User.objects.filter(email="old@example.com").update(is_platform_admin=True)  # bypasses save()
        old = User.objects.get(email="old@example.com")
        api = APIClient()
        api.force_authenticate(old)
        self.assertEqual(api.get("/api/superadmin/stats/").status_code, 403)
        self.assertFalse(api.get("/api/auth/me/").data["is_platform_admin"])

    def test_the_owner_cannot_create_a_second_superadmin_from_the_panel(self):
        owner = User.objects.create_superuser(email=OWNER)
        api = APIClient()
        api.force_authenticate(owner)
        api.post("/api/superadmin/users/create/", {"email": "new@example.com", "is_platform_admin": True}, format="json")
        new = User.objects.filter(email="new@example.com").first()
        self.assertIsNotNone(new)
        self.assertFalse(new.is_platform_admin)
