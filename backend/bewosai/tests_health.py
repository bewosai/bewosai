from unittest import mock

from django.test import TestCase
from rest_framework.test import APIClient


class HealthCheckTests(TestCase):
    def test_kept_database_connections_are_checked_before_reuse(self):
        # Neon closes connections when it suspends after idling; without this
        # the first request after a quiet spell failed (see settings.DATABASES).
        from django.conf import settings

        self.assertTrue(settings.DATABASES["default"]["CONN_HEALTH_CHECKS"])

    def test_plain_health_is_ok(self):
        res = APIClient().get("/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["status"], "ok")

    def test_database_check_reports_ok(self):
        res = APIClient().get("/", {"db": "1"})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["database"], "ok")

    def test_database_check_fails_loudly_when_unreachable(self):
        with mock.patch("django.db.backends.base.base.BaseDatabaseWrapper.cursor", side_effect=RuntimeError("down")):
            res = APIClient().get("/", {"db": "1"})
        self.assertEqual(res.status_code, 503)
        self.assertEqual(res.json()["database"], "unreachable")
