"""
One-time repair: re-sync every sale's and purchase's mirrored bank entry
("SALE-<id>" / "PURCHASE-<id>") with the rule SaleSerializer._sync_bank now
follows — only a confirmed, not-deleted document has moved bank money.

Before that rule, deleting or cancelling a sale/purchase paid by bank or wallet
left its bank entry behind, so the account balance still counted it.

    python manage.py resync_bank_mirrors           # show what would change
    python manage.py resync_bank_mirrors --apply   # change it
"""
from django.core.management.base import BaseCommand
from django.db import transaction

from banking.models import BankTransaction
from purchases.models import Purchase
from purchases.serializers import PurchaseSerializer
from sales.models import Sale
from sales.serializers import SaleSerializer


class Command(BaseCommand):
    help = "Remove bank entries left behind by deleted/cancelled sales and purchases (dry run unless --apply)."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="Make the changes (default: only report them).")

    def handle(self, *args, apply=False, **options):
        stale = []
        for prefix, model in (("SALE-", Sale), ("PURCHASE-", Purchase)):
            refs = BankTransaction.objects.filter(reference__startswith=prefix).values_list("reference", flat=True)
            ids = [int(r[len(prefix):]) for r in refs if r[len(prefix):].isdigit()]
            for doc in model.objects.filter(pk__in=ids).exclude(status="CONFIRMED", is_deleted=False):
                stale.append((prefix, doc))

        for prefix, doc in stale:
            number = getattr(doc, "invoice_number", None) or getattr(doc, "bill_number", "")
            state = "deleted" if doc.is_deleted else doc.status.lower()
            self.stdout.write(f"{prefix}{doc.pk} ({number}, {state}, business {doc.business_id})")

        if not stale:
            self.stdout.write(self.style.SUCCESS("Nothing to fix."))
            return
        if not apply:
            self.stdout.write(self.style.WARNING(f"{len(stale)} bank entr(ies) would be removed. Run with --apply."))
            return
        with transaction.atomic():
            for prefix, doc in stale:
                (SaleSerializer if prefix == "SALE-" else PurchaseSerializer)._sync_bank(doc)
        self.stdout.write(self.style.SUCCESS(f"Removed {len(stale)} stale bank entr(ies)."))
