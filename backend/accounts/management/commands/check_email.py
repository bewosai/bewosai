"""
Checks the email setup, and optionally proves delivery with a real send:

    python manage.py check_email                     # show what's configured + warnings
    python manage.py check_email --to you@gmail.com  # also send a test email

Run it in the Render Shell to test the live setup. Login codes depend on this.
"""
import os

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from bewosai.email import email_provider, send_test_email


class Command(BaseCommand):
    help = "Show the email provider setup and warn about problems; --to sends a real test email."

    def add_arguments(self, parser):
        parser.add_argument("--to", help="Send a test email to this address.")

    def handle(self, *args, to=None, **options):
        provider = email_provider()
        smtp_user = (settings.EMAIL_HOST_USER or "").strip()
        sg_from = (settings.SENDGRID_FROM_EMAIL or "").strip()
        on_render = bool(os.environ.get("RENDER"))

        self.stdout.write(f"Provider used first : {provider}")
        self.stdout.write(f"SendGrid API key    : {'set' if settings.SENDGRID_API_KEY.strip() else 'not set'}")
        self.stdout.write(f"SendGrid sender     : {sg_from or '(none)'}")
        self.stdout.write(f"SMTP (Gmail) user   : {smtp_user or 'not set'}")
        self.stdout.write(f"DEBUG               : {settings.DEBUG}")

        warnings = []
        if provider == "none":
            warnings.append(
                "No email provider is configured. Login codes will NOT be sent"
                + (" (DEBUG is on, so they are only printed to this console)." if settings.DEBUG else " — logins will fail.")
            )
        if provider == "smtp" and on_render:
            warnings.append(
                "Only SMTP is configured and this looks like Render. Render's free plan blocks SMTP "
                "ports 25/465/587, so codes will not send. Set SENDGRID_API_KEY (HTTPS) or upgrade."
            )
        if provider == "sendgrid" and sg_from.lower().endswith(("@gmail.com", "@yahoo.com", "@outlook.com", "@hotmail.com")):
            warnings.append(
                f"SendGrid sends as {sg_from}, a free-mail address. Mail like this often lands in spam "
                "or is rejected. Authenticate a domain you own in SendGrid and send from that."
            )
        for w in warnings:
            self.stdout.write(self.style.WARNING(f"WARNING: {w}"))
        if not warnings:
            self.stdout.write(self.style.SUCCESS("Configuration looks fine."))

        if to:
            self.stdout.write(f"Sending a test email to {to} ...")
            if send_test_email(to):
                self.stdout.write(self.style.SUCCESS("Provider accepted the email. Check the inbox (and spam)."))
            else:
                raise CommandError("The email was NOT sent — see the log lines above for the provider's error.")
