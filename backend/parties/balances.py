"""
Single source of truth for "how much does this party owe us / do we owe them".

Positive = the party owes us (To Receive); negative = we owe them (To Give).
Party.balance, the dashboard totals and the party ledger's closing balance all
derive from here so they can never disagree.

    balance = opening_balance
            + open sale dues               (what they still owe on invoices)
            - open purchase dues           (what we still owe on bills)
            - sale returns                 (credit for goods they sent back)
            + purchase returns             (credit for goods we sent back)
            - unmatched money received     (a payment IN beyond the invoices
                                            it was applied to = an advance)
            + unmatched money paid         (a payment OUT beyond the bills it
                                            was applied to)

Payments are applied to the oldest open invoices when they're recorded
(PartyPaymentListCreateView._reconcile_payment); whatever is left over has no
invoice to reduce, so without the last two terms it vanished — an opening
balance could never be paid down and an advance never showed as a credit.
"""
from decimal import Decimal

from django.db.models import DecimalField, Sum, Value
from django.db.models.functions import Coalesce

ZERO = Decimal("0")


def party_balances(business_id, party_id=None):
    """
    {party_id: Decimal balance} for every non-deleted party of the business
    (or just `party_id`, deleted or not). A handful of grouped queries in total,
    regardless of how many parties there are.
    """
    from purchases.models import Purchase, PurchaseReturn
    from sales.models import Sale, SaleReturn
    from .models import Party, PartyPayment

    parties = Party.objects.filter(business_id=business_id)
    if party_id is None:
        parties = parties.filter(is_deleted=False)
    else:
        parties = parties.filter(pk=party_id)
    balances = {pid: Decimal(opening) for pid, opening in parties.values_list("id", "opening_balance")}
    if not balances:
        return balances

    def only(qs, field):
        return qs.filter(**{field: party_id}) if party_id is not None else qs

    def apply(rows, sign):
        for pid, total in rows:
            if pid in balances and total:
                balances[pid] += sign * total

    sales = only(
        Sale.objects.filter(business_id=business_id, status="CONFIRMED", is_deleted=False), "customer_id"
    )
    apply(sales.order_by().values_list("customer_id").annotate(t=Sum("due_amount")), 1)

    purchases = only(
        Purchase.objects.filter(business_id=business_id, status="CONFIRMED", is_deleted=False), "supplier_id"
    )
    apply(purchases.order_by().values_list("supplier_id").annotate(t=Sum("due_amount")), -1)

    sale_returns = only(
        SaleReturn.objects.filter(
            business_id=business_id, original_sale__status="CONFIRMED", original_sale__is_deleted=False,
        ),
        "original_sale__customer_id",
    )
    apply(
        sale_returns.order_by().values_list("original_sale__customer_id").annotate(t=Sum("amount")), -1,
    )

    purchase_returns = only(
        PurchaseReturn.objects.filter(
            business_id=business_id, original_purchase__status="CONFIRMED", original_purchase__is_deleted=False,
        ),
        "original_purchase__supplier_id",
    )
    apply(
        purchase_returns.order_by().values_list("original_purchase__supplier_id").annotate(t=Sum("amount")), 1,
    )

    payments = only(
        PartyPayment.objects.filter(party__business_id=business_id, is_deleted=False), "party_id"
    ).annotate(
        allocated=Coalesce(
            Sum("allocations__amount"), Value(ZERO), output_field=DecimalField(max_digits=14, decimal_places=2),
        )
    )
    for pid, payment_type, amount, allocated in payments.order_by().values_list(
        "party_id", "payment_type", "amount", "allocated"
    ):
        unmatched = amount - allocated
        if unmatched > 0 and pid in balances:
            balances[pid] += -unmatched if payment_type == "IN" else unmatched

    return balances
