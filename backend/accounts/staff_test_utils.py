"""Test helpers for the staff invitation flow (invite -> email code -> accept)."""
from rest_framework.test import APIClient

from accounts.models import ACCOUNT_BUSINESS, OTPCode


def accept_invite(token, email, code=None, **extra):
    """Accept invitation `token` as `email`, issuing a real one-time code unless
    `code` is given. Returns the API response."""
    if code is None:
        _, code = OTPCode.generate(email, ACCOUNT_BUSINESS)
    return APIClient(**extra).post(
        f"/api/auth/staff-invite/{token}/accept/", {"email": email, "code": code}, format="json",
    )


def signed_in_client(access, business_id):
    client = APIClient(HTTP_X_BUSINESS_ID=str(business_id))
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    return client
