"""
Balance sheet: what the business owns and owes on one date (`as_of`), and the
owner's share — the difference.

    Assets       cash in hand + every bank/wallet account + what customers owe
                 + stock (at purchase price)
    Liabilities  what the business owes suppliers
    Equity       assets − liabilities, split into the profit earned from
                 `date_from` to `as_of` and the owner's capital + earlier profit

Every figure counts only what is dated on or before `as_of`, using the same
rules as the reports it matches (Cash In Hand, Bank Statement, party ledger,
Profit & Loss), so it agrees with them for the same date.

Stock is the one figure the records can't give exactly for a past date:
opening stock and product edits aren't dated, and a stock "Adjustment" sets an
absolute quantity. A past date's stock is worked back from today's by undoing
everything dated after it, and flagged as an estimate.
"""
from datetime import timedelta
from decimal import Decimal

from django.db.models import Case, DecimalField, F, Sum, When
from django.db.models.functions import Coalesce
from django.utils import timezone

ZERO = Decimal("0")
_DEC = DecimalField(max_digits=18, decimal_places=3)


def _sum(qs, expr):
    return qs.aggregate(t=Coalesce(Sum(expr), ZERO, output_field=_DEC))["t"]


def party_balances_as_of(business_id, as_of):
    """{party_id: balance on `as_of`} — positive = they owe us, negative = we
    owe them. The party ledger's running balance on that date; on today's date
    it equals parties.balances.party_balances (tested)."""
    from parties.models import Party, PartyPayment
    from purchases.models import Purchase, PurchaseReturn
    from sales.models import Sale, SaleReturn

    balances = {
        pid: Decimal(opening)
        for pid, opening in Party.objects.filter(business_id=business_id, is_deleted=False)
        .values_list("id", "opening_balance")
    }

    def add(rows, sign):
        for pid, total in rows:
            if pid in balances and total:
                balances[pid] += sign * total

    sales = Sale.objects.filter(
        business_id=business_id, status="CONFIRMED", is_deleted=False, sale_date__lte=as_of,
    ).order_by().values_list("customer_id")
    # The invoice, less what was paid on it at the till (later repayments are
    # their own PartyPayments, counted below).
    add(sales.annotate(t=Sum(F("total") - F("paid_amount") + F("reconciled_amount"))), 1)

    purchases = Purchase.objects.filter(
        business_id=business_id, status="CONFIRMED", is_deleted=False, purchase_date__lte=as_of,
    ).order_by().values_list("supplier_id")
    add(purchases.annotate(t=Sum(F("total") - F("paid_amount") + F("reconciled_amount"))), -1)

    add(SaleReturn.objects.filter(
        business_id=business_id, original_sale__status="CONFIRMED", original_sale__is_deleted=False,
        return_date__lte=as_of,
    ).order_by().values_list("original_sale__customer_id").annotate(
        t=Sum(F("amount") - F("refunded_amount"))), -1)

    add(PurchaseReturn.objects.filter(
        business_id=business_id, original_purchase__status="CONFIRMED", original_purchase__is_deleted=False,
        return_date__lte=as_of,
    ).order_by().values_list("original_purchase__supplier_id").annotate(
        t=Sum(F("amount") - F("refunded_amount"))), 1)

    payments = PartyPayment.objects.filter(
        party__business_id=business_id, is_deleted=False, date__lte=as_of,
    ).order_by()
    add(payments.filter(payment_type="IN").values_list("party_id").annotate(t=Sum("amount")), -1)
    add(payments.filter(payment_type="OUT").values_list("party_id").annotate(t=Sum("amount")), 1)
    return balances


def stock_as_of(business, as_of):
    """([{product rows}], total value, is_estimate) — quantity on `as_of` valued at
    each product's purchase price."""
    from inventory.models import Product, StockMovement
    from purchases.models import PurchaseItem, PurchaseReturnItem
    from sales.models import SaleItem, SaleReturnItem
    from .views import _RETURN_COGS_QTY

    today = timezone.localdate()
    products = list(Product.objects.filter(
        business=business, item_type=Product.PRODUCT, is_deleted=False,
    ).only("id", "name", "stock_quantity", "purchase_price", "created_at"))
    qty = {p.id: p.stock_quantity for p in products}
    is_estimate = as_of < today

    if is_estimate:
        def undo(rows, sign):
            for pid, total in rows:
                if pid in qty and total:
                    qty[pid] += sign * total

        base_qty = Coalesce(F("base_quantity"), F("quantity"), output_field=_DEC)
        undo(SaleItem.objects.filter(
            sale__business=business, sale__status="CONFIRMED", sale__is_deleted=False, sale__sale_date__gt=as_of,
        ).order_by().values_list("product_id").annotate(t=Sum(base_qty)), 1)          # sold since: was still here
        undo(PurchaseItem.objects.filter(
            purchase__business=business, purchase__status="CONFIRMED", purchase__is_deleted=False,
            purchase__purchase_date__gt=as_of,
        ).order_by().values_list("product_id").annotate(t=Sum(base_qty)), -1)         # bought since: wasn't here yet
        undo(SaleReturnItem.objects.filter(
            sale_return__business=business, sale_return__return_date__gt=as_of,
        ).order_by().values_list("product_id").annotate(t=Sum(_RETURN_COGS_QTY)), -1)
        purchase_return_qty = Case(
            When(
                purchase_item__unit_label__iexact=F("purchase_item__product__unit__secondary_unit"),
                purchase_item__product__unit__conversion_factor__isnull=False,
                purchase_item__product__unit__conversion_factor__gt=0,
                then=F("quantity") / F("purchase_item__product__unit__conversion_factor"),
            ),
            default=F("quantity"),
            output_field=_DEC,
        )
        undo(PurchaseReturnItem.objects.filter(
            purchase_return__business=business, purchase_return__return_date__gt=as_of,
        ).order_by().values_list("product_id").annotate(t=Sum(purchase_return_qty)), 1)
        movements = StockMovement.objects.filter(
            product__business=business, created_at__date__gt=as_of,
        ).order_by()
        undo(movements.filter(movement_type__in=["IN", "OPENING"]).values_list("product_id").annotate(t=Sum("quantity")), -1)
        undo(movements.filter(movement_type__in=["OUT", "DAMAGE", "LOST", "TRANSFER"])
             .values_list("product_id").annotate(t=Sum("quantity")), 1)

    rows, total = [], ZERO
    for p in products:
        q = ZERO if timezone.localtime(p.created_at).date() > as_of else max(qty[p.id], ZERO)
        if q == 0:
            continue
        value = (q * p.purchase_price).quantize(Decimal("0.01"))
        total += value
        rows.append({"id": p.id, "name": p.name, "quantity": float(q),
                     "purchase_price": float(p.purchase_price), "value": float(value)})
    rows.sort(key=lambda r: -r["value"])
    return rows, total, is_estimate


def build(business, as_of, date_from):
    from banking.models import BankAccount
    from parties.models import Party
    from .views import CashInHandView, profit_summary

    # Cash in hand: the Cash In Hand ledger's balance at the end of `as_of`.
    cash = sum(
        Decimal(str(e["debit"])) - Decimal(str(e["credit"]))
        for e in CashInHandView._cash_entries(business, date_lt=as_of + timedelta(days=1))
    )

    accounts = []
    for account in BankAccount.objects.filter(business=business, is_deleted=False).order_by("account_name"):
        txns = account.transactions.filter(is_deleted=False, date__lte=as_of)
        balance = (account.opening_balance
                   + _sum(txns.filter(transaction_type="CREDIT"), "amount")
                   - _sum(txns.filter(transaction_type="DEBIT"), "amount"))
        if balance or account.is_active:
            accounts.append({"id": account.id, "name": account.account_name,
                             "type": account.account_type, "balance": float(balance)})
    bank_total = sum(Decimal(str(a["balance"])) for a in accounts)

    balances = party_balances_as_of(business.id, as_of)
    names = dict(Party.objects.filter(pk__in=balances).values_list("id", "name"))
    receivables = sorted(
        ({"id": pid, "name": names.get(pid, ""), "amount": float(b)} for pid, b in balances.items() if b > 0),
        key=lambda r: -r["amount"],
    )
    payables = sorted(
        ({"id": pid, "name": names.get(pid, ""), "amount": float(-b)} for pid, b in balances.items() if b < 0),
        key=lambda r: -r["amount"],
    )
    receivable_total = sum((b for b in balances.values() if b > 0), ZERO)
    payable_total = sum((-b for b in balances.values() if b < 0), ZERO)

    stock_rows, stock_total, stock_is_estimate = stock_as_of(business, as_of)

    profit = profit_summary(business, date_from, as_of)
    period_profit = Decimal(str(profit["net_profit"]))

    assets_total = cash + bank_total + receivable_total + stock_total
    liabilities_total = payable_total
    equity_total = assets_total - liabilities_total

    def money(value):
        return float(Decimal(value).quantize(Decimal("0.01")))

    return {
        "as_of": as_of.isoformat(),
        "date_from": date_from.isoformat(),
        "assets": {
            "cash_in_hand": money(cash),
            "bank_accounts": accounts,
            "bank_total": money(bank_total),
            "receivables": money(receivable_total),
            "receivable_parties": receivables,
            "stock": money(stock_total),
            "stock_items": stock_rows,
            "stock_is_estimate": stock_is_estimate,
            "total": money(assets_total),
        },
        "liabilities": {
            "payables": money(payable_total),
            "payable_parties": payables,
            "total": money(liabilities_total),
        },
        "equity": {
            "period_profit": money(period_profit),
            "capital_and_earlier_profit": money(equity_total - period_profit),
            "total": money(equity_total),
        },
        "profit": profit,
        # Assets = Liabilities + Equity always holds: equity is the difference.
        "liabilities_and_equity_total": money(liabilities_total + equity_total),
    }
