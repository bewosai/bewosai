"""Signing in now counts as activity (see accounts.views). Bring existing
accounts in line: anyone whose last_active_at is empty or older than their
last sign-in gets the sign-in time, so Super Admin stops showing "Never"
next to a real sign-in date."""
from django.db import migrations
from django.db.models import F, Q


def forwards(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    User.objects.filter(last_login_at__isnull=False).filter(
        Q(last_active_at__isnull=True) | Q(last_active_at__lt=F("last_login_at"))
    ).update(last_active_at=F("last_login_at"))


class Migration(migrations.Migration):
    dependencies = [("accounts", "0020_business_invoice_settings")]
    operations = [migrations.RunPython(forwards, migrations.RunPython.noop)]
