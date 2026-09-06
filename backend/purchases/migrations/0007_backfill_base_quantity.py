from django.db import migrations


def backfill(apps, schema_editor):
    PurchaseItem = apps.get_model("purchases", "PurchaseItem")
    for item in PurchaseItem.objects.filter(base_quantity__isnull=True).only("id", "quantity"):
        item.base_quantity = item.quantity
        item.save(update_fields=["base_quantity"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("purchases", "0006_purchaseitem_base_quantity_purchaseitem_unit_label"),
    ]

    operations = [
        migrations.RunPython(backfill, noop),
    ]
