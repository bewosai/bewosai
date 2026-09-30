"""
What happens to later repayments when their invoice or bill goes away.

A party payment (PartyPayment) is applied to the party's open invoices/bills
and remembered as PaymentAllocation rows. If such an invoice is then deleted or
cancelled, the money the customer paid against it must not vanish: take the
allocations off it, and the payment counts as the party's advance/credit again
(parties.balances treats any unallocated part of a payment that way).
"""
from django.db.models import Sum

from .models import PaymentAllocation


def release_allocations(*, sale=None, purchase=None):
    """Undo every party payment applied to `sale` (or `purchase`)."""
    document = sale if sale is not None else purchase
    allocations = PaymentAllocation.objects.filter(sale=sale) if sale is not None \
        else PaymentAllocation.objects.filter(purchase=purchase)
    total = allocations.aggregate(total=Sum("amount"))["total"]
    if not total:
        return
    document.paid_amount -= total
    document.reconciled_amount -= total
    document.save()  # recomputes due_amount
    allocations.delete()
