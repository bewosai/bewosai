from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Sum, Count, Q
from django.db.models.functions import TruncMonth, TruncDay
from datetime import date, timedelta
from accounts.models import Business
from sales.models import Sale
from expenses.models import Expense
from inventory.models import Product
from parties.models import Party
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

        sales_today = Sale.objects.filter(
            business=biz, sale_date=today, status="CONFIRMED"
        ).aggregate(total=Sum("total"))["total"] or 0

        sales_month = Sale.objects.filter(
            business=biz, sale_date__gte=month_start, status="CONFIRMED"
        ).aggregate(total=Sum("total"))["total"] or 0

        expenses_month = Expense.objects.filter(
            business=biz, date__gte=month_start
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_receivable = Sale.objects.filter(
            business=biz, status="CONFIRMED", due_amount__gt=0
        ).aggregate(total=Sum("due_amount"))["total"] or 0

        low_stock = Product.objects.filter(
            business=biz, is_active=True
        ).extra(
            where=["stock_quantity <= low_stock_threshold"]
        ).count()

        recent_sales = Sale.objects.filter(business=biz, status="CONFIRMED").order_by("-created_at")[:5]
        from sales.serializers import SaleSerializer
        recent_sales_data = SaleSerializer(recent_sales, many=True).data

        return Response({
            "sales_today": sales_today,
            "sales_month": sales_month,
            "expenses_month": expenses_month,
            "total_receivable": total_receivable,
            "low_stock_count": low_stock,
            "profit_month": float(sales_month) - float(expenses_month),
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
        products = Product.objects.filter(business=biz, is_active=True)
        total_products = products.count()
        low_stock = products.filter(stock_quantity__lte=F("low_stock_threshold"))
        out_of_stock = products.filter(stock_quantity=0)

        from inventory.serializers import ProductSerializer
        low_stock_data = ProductSerializer(low_stock, many=True).data

        stock_value = products.aggregate(
            value=Sum(F("stock_quantity") * F("purchase_price"))
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
