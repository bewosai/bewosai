from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Sum, Count, Q, F
from django.db.models.functions import TruncMonth, TruncDay
from datetime import date, timedelta
from accounts.models import Business
from sales.models import Sale
from expenses.models import Expense
from inventory.models import Product, StockMovement
from parties.models import Party, PartyPayment
import calendar


def get_biz(request):
    bid = request.query_params.get("business")
    return Business.objects.filter(id=bid, staff__user=request.user, staff__is_active=True).first()


class DashboardSummaryView(APIView):
    def get(self, request):
        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        today = date.today()
        month_start = today.replace(day=1)

        # Sales KPIs
        sales_today = Sale.objects.filter(
            business=biz, sale_date=today, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        sales_month = Sale.objects.filter(
            business=biz, sale_date__gte=month_start, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        # Today's collection (cash received today via sales + payments)
        collection_today_sales = Sale.objects.filter(
            business=biz, sale_date=today, status="CONFIRMED", is_deleted=False
        ).aggregate(total=Sum("paid_amount"))["total"] or 0

        collection_today_payments = PartyPayment.objects.filter(
            party__business=biz, payment_type="IN", date=today
        ).aggregate(total=Sum("amount"))["total"] or 0

        collection_today = float(collection_today_sales) + float(collection_today_payments)

        # Expenses
        expenses_today = Expense.objects.filter(
            business=biz, date=today, is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        expenses_month = Expense.objects.filter(
            business=biz, date__gte=month_start, is_deleted=False
        ).aggregate(total=Sum("amount"))["total"] or 0

        # Receivable & Payable
        total_receivable = Sale.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0, is_deleted=False
        ).aggregate(total=Sum("due_amount"))["total"] or 0

        from purchases.models import Purchase
        total_payable = Purchase.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0, is_deleted=False
        ).aggregate(total=Sum("due_amount"))["total"] or 0

        # Purchases today
        purchases_today = Purchase.objects.filter(
            business=biz, purchase_date=today, is_deleted=False
        ).aggregate(total=Sum("total"))["total"] or 0

        # Low stock
        low_stock = Product.objects.filter(
            business=biz, is_active=True, is_deleted=False, min_stock_level__gt=0,
        ).filter(stock_quantity__lte=F("min_stock_level")).count()

        # Cash balance (rough: total sales paid - total expenses paid in cash)
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
        cash_balance = float(cash_in) + float(cash_in_payments) - float(cash_out_expenses) - float(cash_out_payments)

        # Top selling items (by quantity, last 30 days)
        from sales.models import SaleItem
        top_items = (
            SaleItem.objects.filter(
                sale__business=biz, sale__status="CONFIRMED", sale__is_deleted=False,
                sale__sale_date__gte=today - timedelta(days=30),
            )
            .values("product_name")
            .annotate(total_qty=Sum("quantity"), total_revenue=Sum("total"))
            .order_by("-total_revenue")[:5]
        )

        # Recent sales
        recent_sales = Sale.objects.filter(
            business=biz, status="CONFIRMED", is_deleted=False
        ).order_by("-created_at")[:5]
        from sales.serializers import SaleSerializer
        recent_sales_data = SaleSerializer(recent_sales, many=True).data

        return Response({
            "sales_today": float(sales_today),
            "sales_month": float(sales_month),
            "purchases_today": float(purchases_today),
            "expenses_today": float(expenses_today),
            "expenses_month": float(expenses_month),
            "collection_today": collection_today,
            "total_receivable": float(total_receivable),
            "total_payable": float(total_payable),
            "cash_balance": cash_balance,
            "low_stock_count": low_stock,
            "profit_month": float(sales_month) - float(expenses_month),
            "top_items": list(top_items),
            "recent_sales": recent_sales_data,
        })


class SalesReportView(APIView):
    def get(self, request):
        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        date_from = request.query_params.get("date_from", (date.today() - timedelta(days=30)).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        sales = Sale.objects.filter(
            business=biz, sale_date__range=[date_from, date_to], status="CONFIRMED"
        )

        daily = (
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
            "daily": list(daily),
            "date_from": date_from,
            "date_to": date_to,
        })


class ExpenseReportView(APIView):
    def get(self, request):
        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        date_from = request.query_params.get("date_from", (date.today() - timedelta(days=30)).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        expenses = Expense.objects.filter(business=biz, date__range=[date_from, date_to])

        by_category = (
            expenses.values("category__name", "category__expense_type")
            .annotate(total=Sum("amount"), count=Count("id"))
            .order_by("-total")
        )

        total = expenses.aggregate(total=Sum("amount"))["total"] or 0

        return Response({
            "total": total,
            "by_category": list(by_category),
            "date_from": date_from,
            "date_to": date_to,
        })


class InventoryReportView(APIView):
    def get(self, request):
        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        from django.db.models import F
        products = Product.objects.filter(business=biz, is_active=True, is_deleted=False)
        total_products = products.count()
        low_stock = products.filter(min_stock_level__gt=0, stock_quantity__lte=F("min_stock_level"))
        out_of_stock = products.filter(stock_quantity=0)

        from inventory.serializers import ProductSerializer
        low_stock_data = ProductSerializer(low_stock, many=True).data

        stock_value = products.aggregate(
            value=Sum(F("stock_quantity") * F("buy_price"))
        )["value"] or 0

        return Response({
            "total_products": total_products,
            "low_stock_count": low_stock.count(),
            "out_of_stock_count": out_of_stock.count(),
            "stock_value": stock_value,
            "low_stock_items": low_stock_data,
        })


class ProfitReportView(APIView):
    def get(self, request):
        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        date_from = request.query_params.get("date_from", date.today().replace(day=1).isoformat())
        date_to = request.query_params.get("date_to", date.today().isoformat())

        revenue = Sale.objects.filter(
            business=biz, sale_date__range=[date_from, date_to], status="CONFIRMED"
        ).aggregate(total=Sum("total"))["total"] or 0

        expenses = Expense.objects.filter(
            business=biz, date__range=[date_from, date_to]
        ).aggregate(total=Sum("amount"))["total"] or 0

        return Response({
            "revenue": revenue,
            "expenses": expenses,
            "profit": float(revenue) - float(expenses),
            "date_from": date_from,
            "date_to": date_to,
        })


class MonthlyReportView(APIView):
    def get(self, request):
        import datetime

        biz = get_biz(request)
        if not biz:
            return Response({"error": "Business not found"}, status=404)

        # Last 12 months
        months = []
        now = datetime.date.today()
        for i in range(11, -1, -1):
            m = now.month - i
            y = now.year
            while m <= 0:
                m += 12
                y -= 1
            months.append((y, m))

        result = []
        for (y, m) in months:
            sales = Sale.objects.filter(
                business=biz, is_deleted=False,
                sale_date__year=y, sale_date__month=m
            ).aggregate(total=Sum("total"))["total"] or 0

            exps = Expense.objects.filter(
                business=biz, is_deleted=False,
                date__year=y, date__month=m
            ).aggregate(total=Sum("amount"))["total"] or 0

            result.append({
                "year": y,
                "month": m,
                "revenue": float(sales),
                "expenses": float(exps),
                "profit": float(sales) - float(exps),
            })

        return Response(result)
