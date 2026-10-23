"""The app-store reviewer login: one configured email signs in with a fixed
code and nothing is emailed; everyone else is unaffected; off by default."""
from unittest import mock

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

REVIEW = {"REVIEW_LOGIN_EMAIL": "review@bewosai.com", "REVIEW_LOGIN_CODE": "246810"}


class ReviewLoginTests(TestCase):
    def send(self, email):
        return APIClient().post("/api/auth/send-otp/", {"identifier": email}, format="json")

    def verify(self, email, code):
        return APIClient().post("/api/auth/verify-otp/", {"identifier": email, "code": code}, format="json")

    @override_settings(**REVIEW)
    def test_reviewer_signs_in_with_the_fixed_code_and_no_email_is_sent(self):
        with mock.patch("accounts.views.send_otp_email_quick") as sent:
            self.assertEqual(self.send("Review@Bewosai.com").status_code, 200)
        sent.assert_not_called()
        res = self.verify("review@bewosai.com", "246810")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertIn("access", res.data)

    @override_settings(**REVIEW)
    def test_wrong_code_and_other_accounts_work_as_normal(self):
        self.send("review@bewosai.com")
        self.assertEqual(self.verify("review@bewosai.com", "111111").status_code, 400)
        with mock.patch("accounts.views.send_otp_email_quick", return_value=True) as sent:
            self.send("someone@example.com")
        sent.assert_called_once()
        self.assertEqual(self.verify("someone@example.com", "246810").status_code, 400)

    def test_off_by_default(self):
        with mock.patch("accounts.views.send_otp_email_quick", return_value=True) as sent:
            self.send("review@bewosai.com")
        sent.assert_called_once()
        self.assertEqual(self.verify("review@bewosai.com", "246810").status_code, 400)
