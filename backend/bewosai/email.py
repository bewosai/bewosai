"""
Email sender for Bewosai.
Priority order: SendGrid API key → Gmail SMTP → console (dev fallback).

To use Gmail SMTP, set in .env:
  EMAIL_HOST_USER=your@gmail.com
  EMAIL_HOST_PASSWORD=xxxx xxxx xxxx xxxx   (16-char App Password)

To use SendGrid instead, set:
  SENDGRID_API_KEY=SG.xxxxx
  SENDGRID_FROM_EMAIL=your@gmail.com
"""
import logging
from django.conf import settings
from django.core.mail import send_mail as django_send_mail

logger = logging.getLogger(__name__)

# Set by the two _send_via_* functions on failure so SendOTPView can surface
# the real exception to a trusted debug caller (see LAST_ERROR usage there)
# without needing direct access to Render's log stream.
LAST_ERROR: str | None = None


def _otp_html(otp_code: str, email: str) -> str:
    return f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0"
               style="background:#ffffff;border-radius:16px;overflow:hidden;
                      box-shadow:0 4px 24px rgba(10,37,64,0.10);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#0A2540 0%,#1a3f6b 100%);
                       padding:32px 40px;text-align:center;">
              <h1 style="margin:0;color:#F59E0B;font-size:28px;font-weight:800;
                         letter-spacing:-0.5px;">Bewosai</h1>
              <p style="margin:6px 0 0;color:#93c5fd;font-size:13px;">
                Business Management Platform
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 32px;">
              <h2 style="margin:0 0 8px;color:#0A2540;font-size:20px;font-weight:700;">
                Your Verification Code
              </h2>
              <p style="margin:0 0 28px;color:#64748b;font-size:14px;line-height:1.6;">
                Use the code below to sign in to your Bewosai account.
                It expires in <strong>10 minutes</strong>.
              </p>

              <!-- OTP Box -->
              <div style="background:#f0f7ff;border:2px dashed #3b82f6;
                          border-radius:12px;padding:24px;text-align:center;
                          margin-bottom:28px;">
                <span style="font-size:42px;font-weight:800;letter-spacing:12px;
                             color:#0A2540;font-family:'Courier New',monospace;">
                  {otp_code}
                </span>
              </div>

              <p style="margin:0 0 8px;color:#94a3b8;font-size:12px;line-height:1.6;">
                Never share this code with anyone. Bewosai will never ask for it.
              </p>
              <p style="margin:0;color:#94a3b8;font-size:12px;">
                If you didn't request this, you can safely ignore this email.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#f8fafc;padding:20px 40px;
                       border-top:1px solid #e2e8f0;text-align:center;">
              <p style="margin:0;color:#94a3b8;font-size:12px;">
                &copy; 2025 Bewosai &middot; All rights reserved
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


def send_otp_email(to_email: str, otp_code: str) -> bool:
    """
    Send OTP email.  Returns True on success, False on failure.
    Falls back to console when no credentials are configured.
    """
    api_key = getattr(settings, "SENDGRID_API_KEY", "").strip()
    host_user = getattr(settings, "EMAIL_HOST_USER", "").strip()

    if api_key:
        return _send_via_sendgrid(to_email, otp_code, api_key)

    if host_user:
        return _send_via_smtp(to_email, otp_code)

    _fallback_console(to_email, otp_code)
    return True


def _send_via_sendgrid(to_email: str, otp_code: str, api_key: str) -> bool:
    global LAST_ERROR
    try:
        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail, To, Content

        message = Mail(
            from_email=(settings.SENDGRID_FROM_EMAIL, "Bewosai"),
            to_emails=To(to_email),
            subject="Your Bewosai Verification Code",
        )
        message.add_content(Content(
            "text/plain",
            f"Your Bewosai OTP is: {otp_code}\n\nValid for 10 minutes.\nNever share this code.\n\n— Bewosai Team",
        ))
        message.add_content(Content("text/html", _otp_html(otp_code, to_email)))

        client = SendGridAPIClient(api_key)
        response = client.send(message)

        if response.status_code in (200, 201, 202):
            logger.info("OTP sent via SendGrid to %s (status %s)", to_email, response.status_code)
            return True
        LAST_ERROR = f"SendGrid HTTP {response.status_code}: {response.body}"
        logger.error(
            "SendGrid unexpected status %s for %s: %s",
            response.status_code, to_email, response.body,
        )
        return False
    except Exception as exc:
        LAST_ERROR = f"SendGrid {type(exc).__name__}: {exc}"
        logger.exception("SendGrid send failed for %s: %s", to_email, exc)
        return False


def _send_via_smtp(to_email: str, otp_code: str) -> bool:
    global LAST_ERROR
    try:
        # Gmail's SMTP servers reject mail whose From address doesn't match
        # the authenticated account (or a verified alias of it), so this
        # can't use the generic DEFAULT_FROM_EMAIL — it must be the same
        # mailbox EMAIL_HOST_USER logged in as.
        django_send_mail(
            subject="Your Bewosai Verification Code",
            message=(
                f"Your Bewosai OTP is: {otp_code}\n\n"
                "Valid for 10 minutes. Never share this code.\n\n"
                "— Bewosai Team"
            ),
            from_email=f"Bewosai <{settings.EMAIL_HOST_USER}>",
            recipient_list=[to_email],
            html_message=_otp_html(otp_code, to_email),
            fail_silently=False,
        )
        logger.info("OTP sent via SMTP to %s", to_email)
        return True
    except Exception as exc:
        LAST_ERROR = f"SMTP {type(exc).__name__}: {exc}"
        logger.exception("SMTP send failed for %s: %s", to_email, exc)
        return False


def _fallback_console(to_email: str, otp_code: str) -> None:
    print(
        f"\n{'='*55}\n"
        f"  [BEWOSAI OTP — no email credentials in .env]\n"
        f"  To:   {to_email}\n"
        f"  Code: {otp_code}\n"
        f"  Add EMAIL_HOST_USER + EMAIL_HOST_PASSWORD to .env\n"
        f"  to receive real emails via Gmail.\n"
        f"{'='*55}\n"
    )
