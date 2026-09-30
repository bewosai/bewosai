"""
Switch the Excel Import feature on.

0003_seed_features created it switched off, so on a fresh database (like the
production Neon one) bulk upload of products and parties was refused for
everyone, Premium included. It stays Premium-only, and Super Admin → Feature
Management can still turn it off.
"""
from django.db import migrations


def enable(apps, schema_editor):
    Feature = apps.get_model("superadmin", "Feature")
    Feature.objects.filter(key="excel_import").update(enabled=True)


class Migration(migrations.Migration):
    dependencies = [("superadmin", "0006_alter_license_duration_type")]

    operations = [migrations.RunPython(enable, migrations.RunPython.noop)]
