from django.db import migrations

# Matches the Super Admin "Feature Management" table: key, display name,
# whether it starts enabled, and whether it's gated to the Premium plan.
FEATURES = [
    ("pos", "POS / Sales", True, False),
    ("purchases", "Purchases", True, False),
    ("expenses", "Expenses", True, False),
    ("inventory", "Inventory", True, False),
    ("parties", "Parties", True, False),
    ("payments", "Payments", True, False),
    ("banking", "Banking", True, False),
    ("staff_management", "Staff Management", True, True),
    ("reports", "Reports", True, False),
    ("barcode", "Barcode", False, False),
    ("invoice_printing", "Invoice Printing", True, False),
    ("excel_import", "Excel Import", False, True),
    ("offline_mode", "Offline Mode", True, True),
]


def seed_features(apps, schema_editor):
    Feature = apps.get_model("superadmin", "Feature")
    for key, name, enabled, premium_only in FEATURES:
        Feature.objects.get_or_create(
            key=key,
            defaults={
                "name": name,
                "enabled": enabled,
                "premium_only": premium_only,
            },
        )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("superadmin", "0002_feature"),
    ]

    operations = [
        migrations.RunPython(seed_features, noop),
    ]
