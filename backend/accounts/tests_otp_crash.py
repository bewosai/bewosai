"""
A server-side failure while saving a login must not burn a correct code: the
user should be able to retry the same code once the fault is gone, not be told
"Incorrect code" for a code they typed right.
"""
from unittest import mock

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import ACCOUNT_BUSINESS, LoginActivity, OTPCode, User


class CrashDuringLoginDoesNotBurnTheCodeTests(TestCase):
    def test_same_code_works_on_retry_after_a_server_error(self):
        email = "crash@example.com"
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        client = APIClient(raise_request_exception=False)
        payload = {"identifier": email, "code": code}

        with mock.patch.object(LoginActivity.objects, "create", side_effect=RuntimeError("db down")):
            crashed = client.post("/api/auth/verify-otp/", payload, format="json")
        self.assertEqual(crashed.status_code, 500)
        # Nothing half-saved, and the code is still usable.
        self.assertFalse(User.objects.filter(email=email).exists())
        self.assertTrue(OTPCode.objects.get(identifier=email).is_valid)

        retry = client.post("/api/auth/verify-otp/", payload, format="json")
        self.assertEqual(retry.status_code, 200, retry.content)
        self.assertEqual(LoginActivity.objects.filter(user__email=email).count(), 1)

    def test_a_used_code_is_still_rejected(self):
        # The give-back only happens on a crash — a successful login still consumes the code.
        email = "once@example.com"
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
        client = APIClient()
        payload = {"identifier": email, "code": code}
        self.assertEqual(client.post("/api/auth/verify-otp/", payload, format="json").status_code, 200)
        again = client.post("/api/auth/verify-otp/", payload, format="json")
        self.assertEqual(again.status_code, 400)
        self.assertEqual(LoginActivity.objects.filter(user__email=email).count(), 1)
