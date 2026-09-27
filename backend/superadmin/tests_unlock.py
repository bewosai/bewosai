"""Super Admin opens only after its email is typed and a fresh emailed code is entered."""
import re
from datetime import timedelta
from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import OTPCode, User

OWNER = "mahatok008@gmail.com"


@override_settings(SUPERADMIN_EMAIL=OWNER, SUPERADMIN_UNLOCK_HOURS=12)
class SuperAdminUnlockTests(TestCase):
    def setUp(self):
        cache.clear()
        self.addCleanup(cache.clear)
        self.admin = User.objects.create_superuser(email=OWNER)
        self.api = APIClient()
        self.api.force_authenticate(self.admin)
        self.sent = []
        patcher = mock.patch(
            "bewosai.email.send_otp_email", side_effect=lambda to, code: self.sent.append((to, code)) or True,
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def unlock(self):
        self.assertEqual(self.api.post("/api/superadmin/unlock/send/", {"email": OWNER}, format="json").status_code, 200)
        return self.api.post("/api/superadmin/unlock/verify/", {"code": self.sent[-1][1]}, format="json")

    def test_signed_in_is_not_enough(self):
        res = self.api.get("/api/superadmin/stats/")
        self.assertEqual(res.status_code, 403)
        self.assertTrue(res.data["unlock_required"])
        self.assertFalse(self.api.get("/api/superadmin/unlock/").data["unlocked"])

    def test_email_then_code_opens_it(self):
        res = self.unlock()
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(self.sent[-1][0], OWNER)
        self.assertEqual(self.api.get("/api/superadmin/stats/").status_code, 200)
        self.assertTrue(self.api.get("/api/superadmin/unlock/").data["unlocked"])

    def test_a_different_email_gets_no_code(self):
        res = self.api.post("/api/superadmin/unlock/send/", {"email": "someone@example.com"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(self.sent, [])

    def test_a_wrong_code_keeps_it_locked(self):
        self.api.post("/api/superadmin/unlock/send/", {"email": OWNER}, format="json")
        wrong = "000000" if self.sent[-1][1] != "000000" else "111111"
        self.assertEqual(self.api.post("/api/superadmin/unlock/verify/", {"code": wrong}, format="json").status_code, 400)
        self.assertEqual(self.api.get("/api/superadmin/stats/").status_code, 403)

    def test_it_locks_again_after_twelve_hours(self):
        self.unlock()
        User.objects.filter(pk=self.admin.pk).update(superadmin_unlocked_until=timezone.now() - timedelta(minutes=1))
        self.admin.refresh_from_db()
        self.assertEqual(self.api.get("/api/superadmin/stats/").status_code, 403)

    def test_nobody_else_can_even_ask_for_a_code(self):
        other = User.objects.create_user(email="other@example.com")
        api = APIClient()
        api.force_authenticate(other)
        self.assertEqual(api.post("/api/superadmin/unlock/send/", {"email": "other@example.com"}, format="json").status_code, 403)
        self.assertEqual(api.get("/api/superadmin/unlock/").status_code, 403)
