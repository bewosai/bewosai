"""
Emails business owners whose current fiscal year has ended but is still
open (see accounts.models.FiscalYear / accounts.views.CloseFiscalYearView).
Intended to run on a weekly Render cron job — see render.yaml.
"""
from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import Business, FiscalYear
from accounts.views import _fiscal_year_bounds
from bewosai.email import send_fiscal_year_reminder_email


class Command(BaseCommand):
    help = "Email business owners whose current fiscal year has ended but hasn't been closed yet."

    def handle(self, *args, **options):
        today = timezone.localdate()
        sent = 0

        for business in Business.objects.filter(status=Business.STATUS_ACTIVE).select_related("owner"):
            start, end = _fiscal_year_bounds(business, today)
            if today <= end:
                continue  # current period is still open, nothing to remind about

            already_closed = FiscalYear.objects.filter(
                business=business, start_date=start, status=FiscalYear.STATUS_CLOSED,
            ).exists()
            if already_closed:
                continue

            to_email = business.email or business.owner.email
            if not to_email:
                continue  # no address on file to notify

            label = f"{start.year}/{str(end.year)[2:]}" if start.year != end.year else str(start.year)
            if send_fiscal_year_reminder_email(to_email, business.name, label):
                sent += 1

        self.stdout.write(self.style.SUCCESS(f"Sent {sent} fiscal year reminder email(s)."))
