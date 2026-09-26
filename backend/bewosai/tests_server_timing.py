import re

from django.test import TestCase
from rest_framework.test import APIClient


class ServerTimingHeaderTests(TestCase):
    def test_every_response_says_where_its_time_went(self):
        res = APIClient().post(
            "/api/auth/verify-otp/", {"identifier": "nobody@example.com", "code": "000000"}, format="json",
        )
        header = res["Server-Timing"]
        match = re.fullmatch(r'app;dur=(\d+), db;dur=(\d+);desc="(\d+) queries", cpu;dur=(\d+)', header)
        self.assertIsNotNone(match, header)
        app_ms, db_ms, queries, _cpu_ms = map(int, match.groups())
        self.assertGreater(queries, 0)
        self.assertLessEqual(db_ms, app_ms)

    def test_a_page_with_no_database_work_reports_zero_queries(self):
        self.assertIn('desc="0 queries"', APIClient().get("/")["Server-Timing"])
