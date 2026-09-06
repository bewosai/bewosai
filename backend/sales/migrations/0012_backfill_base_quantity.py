from django.db import migrations


def backfill(apps, schema_editor):
    SaleItem = apps.get_model("sales", "SaleItem")
    for item in SaleItem.objects.filter(base_quantity__isnull=True).only("id", "quantity"):
        item.base_quantity = item.quantity
        item.save(update_fields=["base_quantity"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("sales", "0011_saleitem_base_quantity_saleitem_unit_label"),
    ]

    operations = [
        migrations.RunPython(backfill, noop),
    ]
