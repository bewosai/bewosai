from datetime import date, timedelta

from rest_framework import permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Sum, Count, F, DecimalField, Case, When
from django.db.models.functions import TruncDay, Coalesce

from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.utils import get_business
from sales.models import Sale, SaleItem, SaleReturn, SaleReturnItem
from expenses.models import Expense
from inventory.models import Product
from parties.models import PartyPayment
from purchases.models import Purchase
from banking.models import BankAccount


class _RequireReports:
    """Gated by the Super Admin 'Reports' feature switch. Not applied to
    DashboardSummaryView — that's the home screen, not the dedicated Reports
    section, so it stays available even if 'reports' is switched off."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("reports"), require_staff_permission("reports")]

# Cost of a sold unit: prefer the unit_cost snapshotted on the SaleItem at
# sale time; fall back to the product's current purchase_price only for
# older rows created before unit_cost existed.
_UNIT_COST = Coalesce(F("unit_cost"), F("product__purchase_price"), output_field=DecimalField())
_RETURN_UNIT_COST = Coalesce(
    F("sale_item__unit_cost"), F("sale_item__product__purchase_price"), F("product__purchase_price"),
    output_field=DecimalField(),
)
# unit_cost is always a per-*primary*-unit cost (SaleItem.save() snapshots
# product.purchase_price verbatim, never converted) — so COGS must be paired
# with the primary-unit-equivalent quantity (base_quantity), not the raw
# billed quantity, or a line billed in a secondary unit (e.g. "Piece" when
# the product's primary unit is "Box") would multiply a per-Box cost by a
# Piece count and wildly overstate COGS. Falls back to quantity for rows
# created before base_quantity existed.
_COGS_QTY = Coalesce(F("base_quantity"), F("quantity"), output_field=DecimalField())
# SaleReturnItem has no base_quantity snapshot of its own, so the same
# primary-unit conversion is reconstructed here from the original sale
# item's unit_label/product/unit — mirrors Unit.base_quantity_for exactly
# (only divides by conversion_factor when unit_label matches the
# configured secondary unit; otherwise the quantity is already primary-unit).
_RETURN_COGS_QTY = Case(
    When(
        sale_item__unit_label__iexact=F("sale_item__product__unit__secondary_unit"),
        sale_item__product__unit__conversion_factor__isnull=False,
        sale_item__product__unit__conversion_factor__gt=0,
        then=F("quantity") / F("sale_item__product__unit__conversion_factor"),
    ),
    default=F("quantity"),
    output_field=DecimalField(),
)


def _sale_returns_total(business, date_from, date_to):
    """Revenue given back via SaleReturn within a date range, keyed by return_date."""
    return SaleReturn.objects.filter(
        business=business, return_date__range=[date_from, date_to],
    ).aggregate(total=Sum("amount"))["total"] or 0


def _sale_returns_cogs(business, date_from, date_to):
    """Cost of goods that came back via SaleReturn within a date range — those units
    were restocked, not sold, so their cost must come back out of COGS too."""
    return SaleReturnItem.objects.filter(
        sale_return__business=business, sale_return__return_date__range=[date_from, date_to],
    ).aggregate(total=Sum(_RETURN_COGS_QTY * _RETURN_UNIT_COST))["total"] or 0


class DashboardSummaryView(APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        today = date.today()
        month_start = today.replace(day=1)

        sales_today = Sale.objects.filter(
            business=biz, sale_date=today, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        sales_month = Sale.objects.filter(
            business=biz, sale_date__gte=month_start, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        collection_today_sales = Sale.objects.filter(
            business=biz, sale_date=today, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("paid_amount"))["total"] or 0

        collection_today_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="IN", date=today, is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        expenses_today = Expense.objects.filter(
            business=biz, date=today, is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        expenses_month = Expense.objects.filter(
            business=biz, date__gte=month_start, is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_receivable = Sale.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0, is_deleted=False
        ).aggregate(total=Sum("due_amount"))["total"] or 0

        total_payable = Purchase.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0, is_deleted=False
        ).aggregate(total=Sum("due_amount"))["total"] or 0

        purchases_today = Purchase.objects.filter(
            business=biz, purchase_date=today, is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        # Matches Product.is_low_stock / inventory app's own ?low_stock= filter —
        # min_stock_level defaults to 0 and is unused by any UI, so filtering on it
        # here (as this used to) silently hid every low-stock product from the dashboard.
        low_stock_count = Product.objects.filter(
            business=biz, is_active=True, is_deleted=False,
            stock_quantity__lte=F("low_stock_threshold"),
        ).count()

        cash_in = Sale.objects.filter(
            business=biz, payment_method="CASH", status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("paid_amount"))["total"] or 0
        cash_in_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="IN", payment_method="CASH", is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0
        cash_out_expenses = Expense.objects.filter(
            business=biz, payment_method="CASH", is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0
        cash_out_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="OUT", payment_method="CASH", is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0
        cash_balance = (
            float(cash_in) + float(cash_in_payments)
            - float(cash_out_expenses) - float(cash_out_payments)
        )

        top_items = list(
            SaleItem.objects.filter(
                sale__business=biz,
                sale__status="CONFIRMED",
                sale__is_deleted=False,
                sale__sale_date__gte=today - timedelta(days=30),
            )
            .values("product_name")
            .annotate(total_qty=Sum("quantity"), total_revenue=Sum("total"))
            .order_by("-total_revenue")[:5]
        )

        from sales.serializers import SaleSerializer
        recent_sales = Sale.objects.filter(
            business=biz, status="CONFIRMED", is_deleted=False
        ).order_by("-created_at")[:5]

        cogs_month = SaleItem.objects.filter(
            sale__business=biz,
            sale__sale_date__gte=month_start,
            sale__status="CONFIRMED",
            sale__is_deleted=False,
            product__isnull=False,
        ).aggregate(
            total=Sum(_COGS_QTY * _UNIT_COST)
        )["total"] or 0

        today_iso = today.isoformat()
        month_start_iso = month_start.isoformat()
        sales_returns_month = _sale_returns_total(biz, month_start_iso, today_iso)
        returns_cogs_month = _sale_returns_cogs(biz, month_start_iso, today_iso)

        net_sales_month = float(sales_month) - float(sales_returns_month)
        net_cogs_month = float(cogs_month) - float(returns_cogs_month)

        return Response({
            "sales_today": float(sales_today),
            "sales_month": float(sales_month),
            "purchases_today": float(purchases_today),
            "expenses_today": float(expenses_today),
            "expenses_month": float(expenses_month),
            "collection_today": float(collection_today_sales) + float(collection_today_payments),
            "total_receivable": float(total_receivable),
            "total_payable": float(total_payable),
            "cash_balance": cash_balance,
            "low_stock_count": low_stock_count,
            "cogs_month": net_cogs_month,
            "gross_profit_month": net_sales_month - net_cogs_month,
            "profit_month": net_sales_month - net_cogs_month - float(expenses_month),
            "top_items": top_items,
            "recent_sales": SaleSerializer(recent_sales, many=True).data,
        })


class SalesReportView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", (date.today() - timedelta(days=30)).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        sales = Sale.objects.filter(
            business=biz,
            sale_date__range=[date_from, date_to],
            status="CONFIRMED",
            is_deleted=False,
        )

        daily = list(
            sales.annotate(day=TruncDay("sale_date"))
            .values("day")
            .annotate(total=Sum("total"), count=Count("id"))
            .order_by("day")
        )

        summary = sales.aggregate(
            total_sales=Sum("total"),
            total_paid=Sum("paid_amount"),
            total_due=Sum("due_amount"),
            count=Count("id"),
        )

        return Response({
            "summary": summary,
            "daily": daily,
            "date_from": date_from,
            "date_to": date_to,
        })


class ExpenseReportView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", (date.today() - timedelta(days=30)).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        expenses = Expense.objects.filter(
            business=biz, date__range=[date_from, date_to], is_deleted=False
        )

        by_category = list(
            expenses.values("category__name", "category__expense_type")
            .annotate(total=Sum("amount"), count=Count("id"))
            .order_by("-total")
        )

        total = expenses.aggregate(total=Sum("amount"))["total"] or 0

        return Response({
            "total": total,
            "by_category": by_category,
            "date_from": date_from,
            "date_to": date_to,
        })


class InventoryReportView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        products = Product.objects.filter(business=biz, is_active=True, is_deleted=False)
        # Services always carry stock_quantity=0/low_stock_threshold=0 (see
        # Product.save()), which made every service register as both
        # low-stock and out-of-stock here — contradicting Product.is_low_stock
        # (which explicitly excludes services) and the Stock tab's own "All
        # Products" table below, which already filters item_type=PRODUCT.
        stockable = products.filter(item_type=Product.PRODUCT)
        low_stock = stockable.filter(stock_quantity__lte=F("low_stock_threshold"))
        out_of_stock = stockable.filter(stock_quantity__lte=0)

        # stock_value = sum(purchase_price * stock_quantity) — correct field name
        stock_value = products.aggregate(
            value=Sum(F("stock_quantity") * F("purchase_price"))
        )["value"] or 0

        from inventory.serializers import ProductSerializer
        return Response({
            "total_products": products.count(),
            "low_stock_count": low_stock.count(),
            "out_of_stock_count": out_of_stock.count(),
            "stock_value": float(stock_value),
            "low_stock_items": ProductSerializer(low_stock, many=True).data,
        })


class ProfitReportView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", date.today().replace(day=1).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        confirmed_sales = Sale.objects.filter(
            business=biz,
            sale_date__range=[date_from, date_to],
            status="CONFIRMED",
            is_deleted=False,
        )
        gross_revenue = confirmed_sales.aggregate(total=Sum("total"))["total"] or 0

        # COGS = sum of (qty × unit_cost snapshot) for each item sold
        gross_cogs = SaleItem.objects.filter(
            sale__business=biz,
            sale__sale_date__range=[date_from, date_to],
            sale__status="CONFIRMED",
            sale__is_deleted=False,
            product__isnull=False,
        ).aggregate(
            total=Sum(_COGS_QTY * _UNIT_COST)
        )["total"] or 0

        # Returned goods were never really "sold" — net them out of both
        # revenue and COGS (the cost comes back out too since it was restocked).
        returns_amount = _sale_returns_total(biz, date_from, date_to)
        returns_cogs = _sale_returns_cogs(biz, date_from, date_to)
        revenue = float(gross_revenue) - float(returns_amount)
        cogs = float(gross_cogs) - float(returns_cogs)

        expenses = Expense.objects.filter(
            business=biz, date__range=[date_from, date_to], is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        gross_profit = float(revenue) - float(cogs)
        net_profit   = gross_profit - float(expenses)

        # Monthly trend (last 6 months)
        today = date.today()
        monthly = []
        for i in range(5, -1, -1):
            m = today.month - i
            y = today.year
            while m <= 0:
                m += 12
                y -= 1
            m_start = date(y, m, 1)
            m_end = date(y + 1, 1, 1) - timedelta(days=1) if m == 12 else date(y, m + 1, 1) - timedelta(days=1)
            m_rev_gross = Sale.objects.filter(
                business=biz, sale_date__year=y, sale_date__month=m,
                status="CONFIRMED", is_deleted=False,
            ).aggregate(t=Sum("total"))["t"] or 0
            m_cogs_gross = SaleItem.objects.filter(
                sale__business=biz, sale__sale_date__year=y, sale__sale_date__month=m,
                sale__status="CONFIRMED", sale__is_deleted=False, product__isnull=False,
            ).aggregate(t=Sum(_COGS_QTY * _UNIT_COST))["t"] or 0
            m_returns = _sale_returns_total(biz, m_start.isoformat(), m_end.isoformat())
            m_returns_cogs = _sale_returns_cogs(biz, m_start.isoformat(), m_end.isoformat())
            m_rev = float(m_rev_gross) - float(m_returns)
            m_cogs = float(m_cogs_gross) - float(m_returns_cogs)
            m_exp = Expense.objects.filter(
                business=biz, date__year=y, date__month=m, is_deleted=False,
            ).aggregate(t=Sum("amount"))["t"] or 0
            monthly.append({
                "year": y, "month": m,
                "revenue": float(m_rev), "cogs": float(m_cogs),
                "expenses": float(m_exp),
                "gross_profit": float(m_rev) - float(m_cogs),
                "net_profit": float(m_rev) - float(m_cogs) - float(m_exp),
            })

        return Response({
            "revenue": float(revenue),
            "cogs": float(cogs),
            "gross_profit": gross_profit,
            "expenses": float(expenses),
            "net_profit": net_profit,
            "profit": net_profit,             # keep backward-compat key
            "gross_margin_pct": round(gross_profit / float(revenue) * 100, 1) if revenue else 0,
            "net_margin_pct":   round(net_profit   / float(revenue) * 100, 1) if revenue else 0,
            "monthly": monthly,
            "date_from": date_from,
            "date_to": date_to,
        })


class ReceivableAgingView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        today = date.today()
        outstanding = Sale.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0, is_deleted=False
        )

        def _agg(qs):
            r = qs.aggregate(total=Sum("due_amount"), count=Count("id"))
            return {"count": r["count"] or 0, "total": float(r["total"] or 0)}

        current   = _agg(outstanding.filter(sale_date__gte=today - timedelta(days=30)))
        days31_60 = _agg(outstanding.filter(
            sale_date__gte=today - timedelta(days=60),
            sale_date__lt=today  - timedelta(days=30),
        ))
        days61_90 = _agg(outstanding.filter(
            sale_date__gte=today - timedelta(days=90),
            sale_date__lt=today  - timedelta(days=60),
        ))
        over90    = _agg(outstanding.filter(sale_date__lt=today - timedelta(days=90)))

        total = float(outstanding.aggregate(total=Sum("due_amount"))["total"] or 0)

        # Top 10 overdue customers
        top_debtors = list(
            outstanding.values("customer__name", "customer_id")
            .annotate(total_due=Sum("due_amount"), invoice_count=Count("id"))
            .order_by("-total_due")[:10]
        )

        return Response({
            "total_receivable": total,
            "current":   {**current,   "label": "0-30 days"},
            "days31_60": {**days31_60, "label": "31-60 days"},
            "days61_90": {**days61_90, "label": "61-90 days"},
            "over90":    {**over90,    "label": "90+ days"},
            "top_debtors": top_debtors,
        })


class MonthlyReportView(_RequireReports, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        today = date.today()
        result = []
        for i in range(11, -1, -1):
            month = today.month - i
            year = today.year
            while month <= 0:
                month += 12
                year -= 1

            m_start = date(year, month, 1)
            m_end = (date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)) - timedelta(days=1)

            sales_gross = Sale.objects.filter(
                business=biz, is_deleted=False,
                sale_date__year=year, sale_date__month=month,
                status="CONFIRMED",
            ).aggregate(total=Sum("total"))["total"] or 0

            exps = Expense.objects.filter(
                business=biz, is_deleted=False,
                date__year=year, date__month=month,
            ).aggregate(total=Sum("amount"))["total"] or 0

            cogs_gross = SaleItem.objects.filter(
                sale__business=biz, sale__is_deleted=False,
                sale__sale_date__year=year, sale__sale_date__month=month,
                sale__status="CONFIRMED", product__isnull=False,
            ).aggregate(
                total=Sum(_COGS_QTY * _UNIT_COST)
            )["total"] or 0

            returns_amount = _sale_returns_total(biz, m_start.isoformat(), m_end.isoformat())
            returns_cogs = _sale_returns_cogs(biz, m_start.isoformat(), m_end.isoformat())
            sales = float(sales_gross) - float(returns_amount)
            cogs = float(cogs_gross) - float(returns_cogs)

            gross = float(sales) - float(cogs)
            result.append({
                "year": year,
                "month": month,
                "revenue": float(sales),
                "cogs": float(cogs),
                "gross_profit": gross,
                "expenses": float(exps),
                "profit": gross - float(exps),
            })

        return Response(result)


class DayBookView(_RequireReports, APIView):
    """Daily transaction register — all cash in/out for a given date."""

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        target_date = request.query_params.get("date", date.today().isoformat())
        from parties.models import PartyPayment

        entries = []

        # Sales on this date
        for s in Sale.objects.filter(
            business=biz, sale_date=target_date, status="CONFIRMED", is_deleted=False
        ).select_related("customer"):
            entries.append({
                "date": target_date, "type": "SALE",
                "ref": s.invoice_number,
                "party": s.customer.name if s.customer else "Walk-in",
                "debit": float(s.paid_amount),
                "credit": 0.0,
                "method": s.payment_method,
                "note": s.notes or "",
            })

        # Purchases on this date
        for p in Purchase.objects.filter(
            business=biz, purchase_date=target_date, is_deleted=False
        ).select_related("supplier"):
            entries.append({
                "date": target_date, "type": "PURCHASE",
                "ref": p.bill_number,
                "party": p.supplier.name if p.supplier else "Supplier",
                "debit": 0.0,
                "credit": float(p.paid_amount),
                "method": p.payment_method,
                "note": p.notes or "",
            })

        # Expenses on this date
        for e in Expense.objects.filter(
            business=biz, date=target_date, is_deleted=False
        ).select_related("category"):
            entries.append({
                "date": target_date, "type": "EXPENSE",
                "ref": f"EXP-{e.id}",
                "party": e.category.name if hasattr(e, 'category') and e.category else "",
                "debit": 0.0,
                "credit": float(e.amount),
                "method": getattr(e, "payment_method", "CASH"),
                "note": e.description if hasattr(e, 'description') else "",
            })

        # Direct party payments on this date
        for pay in PartyPayment.objects.filter(
            party__business=biz, date=target_date, is_deleted=False
        ).select_related("party"):
            is_in = pay.payment_type == "IN"
            entries.append({
                "date": target_date, "type": "PAYMENT_IN" if is_in else "PAYMENT_OUT",
                "ref": f"PMT-{pay.id}",
                "party": pay.party.name,
                "debit": float(pay.amount) if is_in else 0.0,
                "credit": 0.0 if is_in else float(pay.amount),
                "method": pay.payment_method,
                "note": pay.note or "",
            })

        total_in  = sum(e["debit"]  for e in entries)
        total_out = sum(e["credit"] for e in entries)

        return Response({
            "date": target_date,
            "entries": entries,
            "total_in":   round(total_in, 2),
            "total_out":  round(total_out, 2),
            "net_cash":   round(total_in - total_out, 2),
        })


class CashFlowView(_RequireReports, APIView):
    """Monthly cash flow — cash in vs cash out by payment method."""

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", date.today().replace(day=1).isoformat())
        date_to   = request.query_params.get("date_to",   date.today().isoformat())
        from parties.models import PartyPayment

        cash_in_sales = Sale.objects.filter(
            business=biz, sale_date__range=[date_from, date_to],
            status="CONFIRMED", is_deleted=False,
        ).aggregate(total=Sum("paid_amount"))["total"] or 0

        cash_in_payments = PartyPayment.objects.filter(
            party__business=biz, date__range=[date_from, date_to],
            payment_type="IN", is_deleted=False,
        ).aggregate(total=Sum("amount"))["total"] or 0

        cash_out_expenses = Expense.objects.filter(
            business=biz, date__range=[date_from, date_to], is_deleted=False,
        ).aggregate(total=Sum("amount"))["total"] or 0

        cash_out_purchases = Purchase.objects.filter(
            business=biz, purchase_date__range=[date_from, date_to], is_deleted=False,
        ).aggregate(total=Sum("paid_amount"))["total"] or 0

        cash_out_payments = PartyPayment.objects.filter(
            party__business=biz, date__range=[date_from, date_to],
            payment_type="OUT", is_deleted=False,
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_in  = float(cash_in_sales) + float(cash_in_payments)
        total_out = float(cash_out_expenses) + float(cash_out_purchases) + float(cash_out_payments)

        return Response({
            "date_from": date_from,
            "date_to": date_to,
            "cash_in": {
                "sales_collection": float(cash_in_sales),
                "party_payments": float(cash_in_payments),
                "total": round(total_in, 2),
            },
            "cash_out": {
                "expenses": float(cash_out_expenses),
                "purchases": float(cash_out_purchases),
                "party_payments": float(cash_out_payments),
                "total": round(total_out, 2),
            },
            "net_cash_flow": round(total_in - total_out, 2),
        })


class StockReportView(_RequireReports, APIView):
    """Full per-product stock valuation list (all active products, not just low-stock alerts)."""

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        products = Product.objects.filter(
            business=biz, item_type=Product.PRODUCT, is_active=True, is_deleted=False,
        ).select_related("category", "unit").order_by("name")

        items = []
        total_qty = 0.0
        total_value = 0.0
        for p in products:
            qty = float(p.stock_quantity)
            value = round(qty * float(p.purchase_price), 2)
            total_qty += qty
            total_value += value
            items.append({
                "id": p.id,
                "name": p.name,
                "category": p.category.name if p.category else "",
                "unit": (p.unit.abbreviation or p.unit.name) if p.unit else "",
                "stock_quantity": qty,
                "purchase_price": float(p.purchase_price),
                "sale_price": float(p.sale_price),
                "stock_value": value,
                "is_low_stock": p.is_low_stock,
            })

        return Response({
            "items": items,
            "total_products": len(items),
            "total_quantity": round(total_qty, 3),
            "total_stock_value": round(total_value, 2),
        })


class CashInHandView(_RequireReports, APIView):
    """Cash-in-hand ledger: running balance of all CASH-payment-method transactions."""

    @staticmethod
    def _cash_entries(biz, date_range=None, date_lt=None):
        sales_qs = Sale.objects.filter(
            business=biz, status="CONFIRMED", is_deleted=False,
            payment_method="CASH", paid_amount__gt=0,
        ).select_related("customer")
        purchases_qs = Purchase.objects.filter(
            business=biz, status="CONFIRMED", is_deleted=False,
            payment_method="CASH", paid_amount__gt=0,
        ).select_related("supplier")
        expenses_qs = Expense.objects.filter(
            business=biz, is_deleted=False, payment_method="CASH",
        ).select_related("category")
        payments_qs = PartyPayment.objects.filter(
            party__business=biz, payment_method="CASH", is_deleted=False,
        ).select_related("party")

        if date_range:
            sales_qs = sales_qs.filter(sale_date__range=date_range)
            purchases_qs = purchases_qs.filter(purchase_date__range=date_range)
            expenses_qs = expenses_qs.filter(date__range=date_range)
            payments_qs = payments_qs.filter(date__range=date_range)
        elif date_lt:
            sales_qs = sales_qs.filter(sale_date__lt=date_lt)
            purchases_qs = purchases_qs.filter(purchase_date__lt=date_lt)
            expenses_qs = expenses_qs.filter(date__lt=date_lt)
            payments_qs = payments_qs.filter(date__lt=date_lt)

        entries = []
        for s in sales_qs:
            entries.append({
                "date": str(s.sale_date), "type": "SALE", "ref": s.invoice_number,
                "party": s.customer.name if s.customer else "Walk-in",
                "debit": float(s.paid_amount), "credit": 0.0,
            })
        for p in purchases_qs:
            entries.append({
                "date": str(p.purchase_date), "type": "PURCHASE", "ref": p.bill_number,
                "party": p.supplier.name if p.supplier else "Supplier",
                "debit": 0.0, "credit": float(p.paid_amount),
            })
        for e in expenses_qs:
            entries.append({
                "date": str(e.date), "type": "EXPENSE", "ref": f"EXP-{e.id}",
                "party": e.category.name if e.category else "",
                "debit": 0.0, "credit": float(e.amount),
            })
        for pay in payments_qs:
            is_in = pay.payment_type == "IN"
            entries.append({
                "date": str(pay.date), "type": "PAYMENT_IN" if is_in else "PAYMENT_OUT",
                "ref": f"PMT-{pay.id}", "party": pay.party.name,
                "debit": float(pay.amount) if is_in else 0.0,
                "credit": 0.0 if is_in else float(pay.amount),
            })
        return entries

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", date.today().replace(day=1).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        opening_entries = self._cash_entries(biz, date_lt=date_from)
        opening_balance = sum(e["debit"] - e["credit"] for e in opening_entries)

        entries = self._cash_entries(biz, date_range=[date_from, date_to])
        entries.sort(key=lambda x: x["date"])

        balance = opening_balance
        for e in entries:
            balance += e["debit"] - e["credit"]
            e["balance"] = round(balance, 2)

        total_in = sum(e["debit"] for e in entries)
        total_out = sum(e["credit"] for e in entries)

        return Response({
            "date_from": date_from,
            "date_to": date_to,
            "opening_balance": round(opening_balance, 2),
            "entries": entries,
            "total_in": round(total_in, 2),
            "total_out": round(total_out, 2),
            "closing_balance": round(balance, 2),
        })


class BankStatementView(_RequireReports, APIView):
    """Without ?account=: list of bank accounts with current balances (for the picker).
    With ?account=<id>: running-balance statement for that account over a date range."""

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        accounts_qs = BankAccount.objects.filter(business=biz, is_active=True)
        account_id = request.query_params.get("account")

        if not account_id:
            accounts = [{
                "id": a.id, "account_name": a.account_name, "bank_name": a.bank_name,
                "account_type": a.account_type, "opening_balance": float(a.opening_balance),
                "balance": float(a.balance),
            } for a in accounts_qs]
            return Response({"accounts": accounts})

        try:
            account = accounts_qs.get(pk=account_id)
        except BankAccount.DoesNotExist:
            return Response({"error": "Bank account not found."}, status=404)

        date_from = request.query_params.get("date_from", date.today().replace(day=1).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        prior_credit = account.transactions.filter(
            date__lt=date_from, transaction_type="CREDIT"
        ).aggregate(t=Sum("amount"))["t"] or 0
        prior_debit = account.transactions.filter(
            date__lt=date_from, transaction_type="DEBIT"
        ).aggregate(t=Sum("amount"))["t"] or 0
        opening = float(account.opening_balance) + float(prior_credit) - float(prior_debit)

        txns = account.transactions.filter(date__range=[date_from, date_to]).order_by("date", "created_at")

        entries = []
        balance = opening
        for t in txns:
            is_credit = t.transaction_type == "CREDIT"
            balance += float(t.amount) if is_credit else -float(t.amount)
            entries.append({
                "date": str(t.date), "type": t.transaction_type,
                "description": t.description, "reference": t.reference,
                "debit": float(t.amount) if not is_credit else 0.0,
                "credit": float(t.amount) if is_credit else 0.0,
                "balance": round(balance, 2),
            })

        total_credit = sum(e["credit"] for e in entries)
        total_debit = sum(e["debit"] for e in entries)

        return Response({
            "account": {
                "id": account.id, "account_name": account.account_name,
                "bank_name": account.bank_name, "account_type": account.account_type,
            },
            "date_from": date_from,
            "date_to": date_to,
            "opening_balance": round(opening, 2),
            "entries": entries,
            "total_credit": round(total_credit, 2),
            "total_debit": round(total_debit, 2),
            "closing_balance": round(balance, 2),
        })


class AllTransactionsView(_RequireReports, APIView):
    """Combined feed of sales, purchases, expenses, party payments, and bank transactions
    across a date range — the 'All Transaction Report'."""

    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        date_from = request.query_params.get("date_from", (date.today() - timedelta(days=30)).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())
        type_filter = (request.query_params.get("type") or "").upper()

        entries = []

        if not type_filter or type_filter == "SALE":
            for s in Sale.objects.filter(
                business=biz, status="CONFIRMED", is_deleted=False,
                sale_date__range=[date_from, date_to],
            ).select_related("customer"):
                entries.append({
                    "date": str(s.sale_date), "type": "SALE", "ref": s.invoice_number,
                    "party": s.customer.name if s.customer else "Walk-in",
                    "amount": float(s.total), "paid": float(s.paid_amount), "due": float(s.due_amount),
                    "method": s.payment_method,
                })

        if not type_filter or type_filter == "PURCHASE":
            for p in Purchase.objects.filter(
                business=biz, status="CONFIRMED", is_deleted=False,
                purchase_date__range=[date_from, date_to],
            ).select_related("supplier"):
                entries.append({
                    "date": str(p.purchase_date), "type": "PURCHASE", "ref": p.bill_number,
                    "party": p.supplier.name if p.supplier else "Supplier",
                    "amount": float(p.total), "paid": float(p.paid_amount), "due": float(p.due_amount),
                    "method": p.payment_method,
                })

        if not type_filter or type_filter == "EXPENSE":
            for e in Expense.objects.filter(
                business=biz, is_deleted=False, date__range=[date_from, date_to],
            ).select_related("category"):
                entries.append({
                    "date": str(e.date), "type": "EXPENSE", "ref": f"EXP-{e.id}",
                    "party": e.category.name if e.category else "",
                    "amount": float(e.amount), "paid": float(e.amount), "due": 0.0,
                    "method": e.payment_method,
                })

        if not type_filter or type_filter == "PAYMENT":
            for pay in PartyPayment.objects.filter(
                party__business=biz, date__range=[date_from, date_to], is_deleted=False,
            ).select_related("party"):
                is_in = pay.payment_type == "IN"
                entries.append({
                    "date": str(pay.date), "type": "PAYMENT_IN" if is_in else "PAYMENT_OUT",
                    "ref": f"PMT-{pay.id}", "party": pay.party.name,
                    "amount": float(pay.amount), "paid": float(pay.amount), "due": 0.0,
                    "method": pay.payment_method,
                })

        if not type_filter or type_filter == "BANK":
            from banking.models import BankTransaction
            for t in BankTransaction.objects.filter(
                account__business=biz, date__range=[date_from, date_to],
            ).select_related("account"):
                entries.append({
                    "date": str(t.date), "type": f"BANK_{t.transaction_type}",
                    "ref": t.reference or f"TXN-{t.id}", "party": t.account.account_name,
                    "amount": float(t.amount), "paid": float(t.amount), "due": 0.0,
                    "method": t.account.account_type,
                })

        entries.sort(key=lambda x: x["date"], reverse=True)

        total_sales = sum(e["amount"] for e in entries if e["type"] == "SALE")
        total_purchases = sum(e["amount"] for e in entries if e["type"] == "PURCHASE")
        total_expenses = sum(e["amount"] for e in entries if e["type"] == "EXPENSE")

        return Response({
            "date_from": date_from,
            "date_to": date_to,
            "entries": entries,
            "count": len(entries),
            "summary": {
                "total_sales": round(total_sales, 2),
                "total_purchases": round(total_purchases, 2),
                "total_expenses": round(total_expenses, 2),
            },
        })
