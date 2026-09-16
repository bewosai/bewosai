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
    return _send(
        to_email,
        subject="Your Bewosai Verification Code",
        text=f"Your Bewosai OTP is: {otp_code}\n\nValid for 10 minutes.\nNever share this code.\n\n— Bewosai Team",
        html=_otp_html(otp_code, to_email),
        console_fallback=lambda: _fallback_console(to_email, otp_code),
    )


def _fiscal_year_reminder_html(business_name: str, label: str) -> str:
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
          <tr>
            <td style="padding:40px 40px 32px;">
              <h2 style="margin:0 0 8px;color:#0A2540;font-size:20px;font-weight:700;">
                Fiscal Year {label} Has Ended
              </h2>
              <p style="margin:0 0 8px;color:#64748b;font-size:14px;line-height:1.6;">
                <strong>{business_name}</strong>'s fiscal year {label} has ended but hasn't
                been closed in Bewosai yet.
              </p>
              <p style="margin:0;color:#64748b;font-size:14px;line-height:1.6;">
                Go to Settings &rarr; Advanced in Bewosai to close it whenever you're ready.
              </p>
            </td>
          </tr>
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


def send_fiscal_year_reminder_email(to_email: str, business_name: str, label: str) -> bool:
    """
    Remind a business owner that their current fiscal year period has ended
    and is still open. Returns True on success, False on failure. Falls back
    to console when no credentials are configured (same as send_otp_email).
    """
    return _send(
        to_email,
        subject=f"Bewosai: Fiscal Year {label} Has Ended",
        text=(
            f"{business_name}'s fiscal year {label} has ended but hasn't been closed "
            "in Bewosai yet.\n\nGo to Settings > Advanced in Bewosai to close it whenever "
            "you're ready.\n\n— Bewosai Team"
        ),
        html=_fiscal_year_reminder_html(business_name, label),
        console_fallback=lambda: print(
            f"\n{'='*55}\n"
            f"  [BEWOSAI FISCAL YEAR REMINDER — no email credentials in .env]\n"
            f"  To:      {to_email}\n"
            f"  Business:{business_name}\n"
            f"  Period:  {label}\n"
            f"{'='*55}\n"
        ),
    )


def _send(to_email: str, *, subject: str, text: str, html: str, console_fallback) -> bool:
    api_key = getattr(settings, "SENDGRID_API_KEY", "").strip()
    host_user = getattr(settings, "EMAIL_HOST_USER", "").strip()

    if api_key:
        return _send_via_sendgrid(to_email, subject, text, html, api_key)

    if host_user:
        return _send_via_smtp(to_email, subject, text, html)

    console_fallback()
    return True


def _send_via_sendgrid(to_email: str, subject: str, text: str, html: str, api_key: str) -> bool:
    try:
        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail, To, Content

        message = Mail(
            from_email=(settings.SENDGRID_FROM_EMAIL, "Bewosai"),
            to_emails=To(to_email),
            subject=subject,
        )
        message.add_content(Content("text/plain", text))
        message.add_content(Content("text/html", html))

        client = SendGridAPIClient(api_key)
        response = client.send(message)

        if response.status_code in (200, 201, 202):
            logger.info("Email sent via SendGrid to %s (status %s)", to_email, response.status_code)
            return True
        logger.error(
            "SendGrid unexpected status %s for %s: %s",
            response.status_code, to_email, response.body,
        )
        return False
    except Exception as exc:
        body = getattr(exc, "body", None)
        detail = body.decode() if isinstance(body, bytes) else body
        logger.exception(
            "SendGrid send failed for %s: %s%s", to_email, exc, f" | body: {detail}" if detail else "",
        )
        return False


def _send_via_smtp(to_email: str, subject: str, text: str, html: str) -> bool:
    try:
        # Gmail's SMTP servers reject mail whose From address doesn't match
        # the authenticated account (or a verified alias of it), so this
        # can't use the generic DEFAULT_FROM_EMAIL — it must be the same
        # mailbox EMAIL_HOST_USER logged in as.
        django_send_mail(
            subject=subject,
            message=text,
            from_email=f"Bewosai <{settings.EMAIL_HOST_USER}>",
            recipient_list=[to_email],
            html_message=html,
            fail_silently=False,
        )
        logger.info("Email sent via SMTP to %s", to_email)
        return True
    except Exception as exc:
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
