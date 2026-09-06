"""
SMS sender for Bewosai — Sparrow SMS (sparrowsms.com), Nepal-only gateway.

Sparrow's basic v2 API only delivers to 10-digit Nepali mobile numbers, so
this is used for +977 numbers only; other country codes aren't supported by
this gateway and callers should reject them before reaching here.

To enable real sending, set in .env / Render env vars:
  SPARROW_TOKEN=xxxxx        (from the Sparrow dashboard)
  SPARROW_IDENTITY=Bewosai   (your approved sender identity, if different)

Without SPARROW_TOKEN, falls back to printing the code to the console so
local development still works without a Sparrow account.
"""
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

SPARROW_SMS_URL = "https://api.sparrowsms.com/v2/sms/"


def send_otp_sms(phone_local: str, otp_code: str) -> bool:
    """
    Send an OTP SMS to a 10-digit Nepali mobile number (no country code
    prefix — Sparrow's `to` param expects the bare local number).
    Returns True on success, False on failure.
    """
    token = getattr(settings, "SPARROW_TOKEN", "").strip()
    if not token:
        _fallback_console(phone_local, otp_code)
        return True

    identity = getattr(settings, "SPARROW_IDENTITY", "Bewosai").strip() or "Bewosai"
    text = f"Your Bewosai verification code is {otp_code}. Valid for 10 minutes. Do not share it with anyone."

    try:
        response = requests.get(
            SPARROW_SMS_URL,
            params={"token": token, "from": identity, "to": phone_local, "text": text},
            timeout=15,
        )
        data = response.json()
        if response.status_code == 200 and data.get("response_code") == 200:
            logger.info("OTP sent via Sparrow SMS to %s", phone_local)
            return True
        logger.error("Sparrow SMS unexpected response for %s: %s", phone_local, data)
        return False
    except Exception as exc:
        logger.exception("Sparrow SMS send failed for %s: %s", phone_local, exc)
        return False


def _fallback_console(phone_local: str, otp_code: str) -> None:
    print(
        f"\n{'='*55}\n"
        f"  [BEWOSAI OTP — no SPARROW_TOKEN in .env]\n"
        f"  To:   {phone_local}\n"
        f"  Code: {otp_code}\n"
        f"  Add SPARROW_TOKEN to .env to send real SMS via Sparrow.\n"
        f"{'='*55}\n"
    )
