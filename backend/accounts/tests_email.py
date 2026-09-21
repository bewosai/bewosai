"""
Every email the backend sends (login codes, fiscal-year reminders) goes through
bewosai.email._send. It must fall back sensibly when a provider fails, never
claim success when nothing was sent, and survive one bad recipient in a batch.
"""
from datetime import date
from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase, TestCase, override_settings

from accounts.models import Business, User
from bewosai import email as mail

SENDGRID = "bewosai.email._send_via_sendgrid"
SMTP = "bewosai.email._send_via_smtp"


def send(**kw):
    return mail.send_otp_email("someone@example.com", "123456")


@override_settings(SENDGRID_API_KEY="SG.fake", EMAIL_HOST_USER="me@gmail.com", DEBUG=False)
class ProviderFallbackTests(SimpleTestCase):
    def test_sendgrid_success_does_not_touch_smtp(self):
        with mock.patch(SENDGRID, return_value=True) as sg, mock.patch(SMTP) as smtp:
            self.assertTrue(send())
        sg.assert_called_once()
        smtp.assert_not_called()

    def test_sendgrid_failure_falls_back_to_smtp(self):
        with mock.patch(SENDGRID, return_value=False), mock.patch(SMTP, return_value=True) as smtp:
            self.assertTrue(send())
        smtp.assert_called_once()

    def test_both_failing_reports_failure(self):
        with mock.patch(SENDGRID, return_value=False), mock.patch(SMTP, return_value=False):
            self.assertFalse(send())

    @override_settings(EMAIL_HOST_USER="")
    def test_sendgrid_failure_with_no_smtp_reports_failure(self):
        with mock.patch(SENDGRID, return_value=False), mock.patch(SMTP) as smtp:
            self.assertFalse(send())
        smtp.assert_not_called()


class NoProviderTests(SimpleTestCase):
    @override_settings(SENDGRID_API_KEY="", EMAIL_HOST_USER="", DEBUG=False)
    def test_no_provider_is_a_failure_outside_debug(self):
        with mock.patch("builtins.print"):
            self.assertFalse(send())

    @override_settings(SENDGRID_API_KEY="", EMAIL_HOST_USER="", DEBUG=True)
    def test_no_provider_in_debug_prints_and_succeeds(self):
        with mock.patch("builtins.print") as printed:
            self.assertTrue(send())
        self.assertIn("123456", str(printed.call_args_list))

    @override_settings(SENDGRID_API_KEY="", EMAIL_HOST_USER="me@gmail.com")
    def test_smtp_only(self):
        with mock.patch(SMTP, return_value=True) as smtp:
            self.assertTrue(send())
        smtp.assert_called_once()


class ReminderEmailContentTests(SimpleTestCase):
    def test_business_name_is_html_escaped(self):
        html = mail._fiscal_year_reminder_html('<b>Ram & Sons</b>', "2025/26")
        self.assertNotIn("<b>Ram", html)
        self.assertIn("&lt;b&gt;Ram &amp; Sons&lt;/b&gt;", html)

    def test_footer_year_is_current(self):
        from django.utils import timezone
        self.assertIn(str(timezone.now().year), mail._otp_html("123456", "a@b.com"))
        self.assertNotIn("2025 Bewosai", mail._otp_html("123456", "a@b.com").replace(str(timezone.now().year), ""))


class ReminderJobTests(TestCase):
    def make_business(self, owner_email, name):
        owner = User.objects.create_user(email=owner_email, name="Owner")
        return Business.objects.create(owner=owner, name=name)

    def run_job(self, sender):
        out, err = StringIO(), StringIO()
        past = (date(2020, 1, 1), date(2020, 12, 31))
        with mock.patch("accounts.management.commands.send_fiscal_year_reminders._fiscal_year_bounds", return_value=past), \
             mock.patch("accounts.management.commands.send_fiscal_year_reminders.send_fiscal_year_reminder_email", side_effect=sender):
            call_command("send_fiscal_year_reminders", stdout=out, stderr=err)
        return out.getvalue(), err.getvalue()

    def test_one_failure_does_not_stop_the_others_and_is_reported(self):
        self.make_business("a@example.com", "Alpha")
        self.make_business("b@example.com", "Beta")
        self.make_business("c@example.com", "Gamma")

        def sender(to, name, label):
            if to == "b@example.com":
                raise RuntimeError("provider exploded")
            return True

        out, err = self.run_job(sender)
        self.assertIn("Sent 2 fiscal year reminder", out)
        self.assertIn("1 reminder(s) could NOT be sent: b@example.com", out)
        self.assertIn("b@example.com raised", err)

    def test_a_false_return_is_counted_as_failed(self):
        self.make_business("a@example.com", "Alpha")
        out, _ = self.run_job(lambda to, name, label: False)
        self.assertIn("Sent 0 fiscal year reminder", out)
        self.assertIn("could NOT be sent: a@example.com", out)


class CheckEmailCommandTests(SimpleTestCase):
    def run_cmd(self, *args):
        out = StringIO()
        call_command("check_email", *args, stdout=out)
        return out.getvalue()

    @override_settings(SENDGRID_API_KEY="", EMAIL_HOST_USER="", DEBUG=False)
    def test_warns_when_nothing_is_configured(self):
        self.assertIn("No email provider is configured", self.run_cmd())

    @override_settings(SENDGRID_API_KEY="SG.x", SENDGRID_FROM_EMAIL="me@gmail.com")
    def test_warns_about_a_freemail_sender(self):
        self.assertIn("free-mail address", self.run_cmd())

    @override_settings(SENDGRID_API_KEY="SG.x", SENDGRID_FROM_EMAIL="noreply@bewosai.com")
    def test_clean_config_has_no_warnings(self):
        self.assertIn("Configuration looks fine", self.run_cmd())

    @override_settings(SENDGRID_API_KEY="SG.x", SENDGRID_FROM_EMAIL="noreply@bewosai.com")
    def test_test_send_success_and_failure(self):
        with mock.patch("accounts.management.commands.check_email.send_test_email", return_value=True):
            self.assertIn("Provider accepted", self.run_cmd("--to", "me@example.com"))
        with mock.patch("accounts.management.commands.check_email.send_test_email", return_value=False):
            with self.assertRaises(CommandError):
                self.run_cmd("--to", "me@example.com")
