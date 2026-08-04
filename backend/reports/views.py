from datetime import date, timedelta

from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Sum, Count, F
from django.db.models.functions import TruncDay

from bewosy.utils import get_business
from sales.models import Sale, SaleItem
from expenses.models import Expense
from inventory.models import Product
from parties.models import PartyPayment
from purchases.models import Purchase


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
            party__business=biz, payment_type="IN", date=today
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

        low_stock_count = Product.objects.filter(
            business=biz, is_active=True, is_deleted=False, min_stock_level__gt=0,
            stock_quantity__lte=F("min_stock_level"),
        ).count()

        cash_in = Sale.objects.filter(
            business=biz, payment_method="CASH", status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("paid_amount"))["total"] or 0
        cash_in_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="IN", payment_method="CASH"
        ).aggregate(total=Sum("amount"))["total"] or 0
        cash_out_expenses = Expense.objects.filter(
            business=biz, payment_method="CASH", is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0
        cash_out_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="OUT", payment_method="CASH"
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

        from django.db.models import F as _F
        cogs_month = SaleItem.objects.filter(
            sale__business=biz,
            sale__sale_date__gte=month_start,
            sale__status="CONFIRMED",
            sale__is_deleted=False,
            product__isnull=False,
        ).aggregate(
            total=Sum(_F("quantity") * _F("product__purchase_price"))
        )["total"] or 0

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
            "cogs_month": float(cogs_month),
            "gross_profit_month": float(sales_month) - float(cogs_month),
            "profit_month": float(sales_month) - float(cogs_month) - float(expenses_month),
            "top_items": top_items,
            "recent_sales": SaleSerializer(recent_sales, many=True).data,
        })


class SalesReportView(APIView):
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


class ExpenseReportView(APIView):
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


class InventoryReportView(APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=404)

        products = Product.objects.filter(business=biz, is_active=True, is_deleted=False)
        low_stock = products.filter(
            min_stock_level__gt=0, stock_quantity__lte=F("min_stock_level")
        )
        out_of_stock = products.filter(stock_quantity__lte=0)

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


class ProfitReportView(APIView):
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
        revenue = confirmed_sales.aggregate(total=Sum("total"))["total"] or 0

        # COGS = sum of (qty × product.purchase_price) for each item sold
        cogs = SaleItem.objects.filter(
            sale__business=biz,
            sale__sale_date__range=[date_from, date_to],
            sale__status="CONFIRMED",
            sale__is_deleted=False,
            product__isnull=False,
        ).aggregate(
            total=Sum(F("quantity") * F("product__purchase_price"))
        )["total"] or 0

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
            m_rev = Sale.objects.filter(
                business=biz, sale_date__year=y, sale_date__month=m,
                status="CONFIRMED", is_deleted=False,
            ).aggregate(t=Sum("total"))["t"] or 0
            m_cogs = SaleItem.objects.filter(
                sale__business=biz, sale__sale_date__year=y, sale__sale_date__month=m,
                sale__status="CONFIRMED", sale__is_deleted=False, product__isnull=False,
            ).aggregate(t=Sum(F("quantity") * F("product__purchase_price")))["t"] or 0
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


class ReceivableAgingView(APIView):
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


class MonthlyReportView(APIView):
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

            sales = Sale.objects.filter(
                business=biz, is_deleted=False,
                sale_date__year=year, sale_date__month=month,
                status="CONFIRMED",
            ).aggregate(total=Sum("total"))["total"] or 0

            exps = Expense.objects.filter(
                business=biz, is_deleted=False,
                date__year=year, date__month=month,
            ).aggregate(total=Sum("amount"))["total"] or 0

            cogs = SaleItem.objects.filter(
                sale__business=biz, sale__is_deleted=False,
                sale__sale_date__year=year, sale__sale_date__month=month,
                sale__status="CONFIRMED", product__isnull=False,
            ).aggregate(
                total=Sum(F("quantity") * F("product__purchase_price"))
            )["total"] or 0

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


class DayBookView(APIView):
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
            party__business=biz, date=target_date
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


class CashFlowView(APIView):
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
            payment_type="IN",
        ).aggregate(total=Sum("amount"))["total"] or 0

        cash_out_expenses = Expense.objects.filter(
            business=biz, date__range=[date_from, date_to], is_deleted=False,
        ).aggregate(total=Sum("amount"))["total"] or 0

        cash_out_purchases = Purchase.objects.filter(
            business=biz, purchase_date__range=[date_from, date_to], is_deleted=False,
        ).aggregate(total=Sum("paid_amount"))["total"] or 0

        cash_out_payments = PartyPayment.objects.filter(
            party__business=biz, date__range=[date_from, date_to],
            payment_type="OUT",
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
