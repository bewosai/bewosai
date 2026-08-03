import re

from rest_framework import generics, status, parsers
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone

from bewosy.utils import get_bid, get_business
from .models import Purchase, PurchaseReturn
from .serializers import PurchaseSerializer, PurchaseReturnSerializer


def _next_bill_number(business):
    last = Purchase.objects.filter(business=business).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.bill_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    return f"PUR-{num:04d}"


class PurchaseNextNumberView(APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response({"next_number": _next_bill_number(biz)})


class PurchaseListCreateView(generics.ListCreateAPIView):
    serializer_class = PurchaseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        biz = get_business(self.request)
        if not biz:
            return Purchase.objects.none()
        qs = Purchase.objects.filter(business=biz, is_deleted=False).select_related(
            "supplier", "created_by"
        )
        supplier = self.request.query_params.get("supplier")
        if supplier:
            qs = qs.filter(supplier_id=supplier)
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(purchase_date__gte=date_from)
        if date_to:
            qs = qs.filter(purchase_date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        biz = get_business(self.request)
        bill_number = self.request.data.get("bill_number") or _next_bill_number(biz)
        serializer.save(
            business=biz,
            bill_number=bill_number,
            created_by=self.request.user,
        )


class PurchaseDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PurchaseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        biz = get_business(self.request)
        return Purchase.objects.filter(business=biz, is_deleted=False)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])


class PurchaseReturnListCreateView(generics.ListCreateAPIView):
    serializer_class = PurchaseReturnSerializer

    def get_queryset(self):
        biz = get_business(self.request)
        if not biz:
            return PurchaseReturn.objects.none()
        return PurchaseReturn.objects.filter(business=biz)

    def perform_create(self, serializer):
        biz = get_business(self.request)
        serializer.save(business=biz, created_by=self.request.user)


class RecycleBinView(APIView):
    """Lists all soft-deleted records across models for the current business."""

    def get(self, request):
        from sales.models import Sale
        from parties.models import Party
        from expenses.models import Expense
        from inventory.models import Product

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        result = []
        for sale in Sale.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "sale",
                "id": sale.id,
                "label": f"Invoice {sale.invoice_number}",
                "deleted_at": sale.deleted_at,
            })
        for purchase in Purchase.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "purchase",
                "id": purchase.id,
                "label": f"Purchase {purchase.bill_number}",
                "deleted_at": purchase.deleted_at,
            })
        for party in Party.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "party",
                "id": party.id,
                "label": f"Party: {party.name}",
                "deleted_at": party.deleted_at,
            })
        for expense in Expense.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "expense",
                "id": expense.id,
                "label": f"Expense Rs.{expense.amount} ({expense.date})",
                "deleted_at": expense.deleted_at,
            })
        for product in Product.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "product",
                "id": product.id,
                "label": f"Product: {product.name}",
                "deleted_at": product.deleted_at,
            })

        result.sort(key=lambda x: x["deleted_at"] or timezone.now(), reverse=True)
        return Response(result)


class RecycleBinRestoreView(APIView):
    def post(self, request, record_type, pk):
        from sales.models import Sale
        from parties.models import Party
        from expenses.models import Expense
        from inventory.models import Product

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            if record_type == "sale":
                obj = Sale.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "purchase":
                obj = Purchase.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "party":
                obj = Party.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "expense":
                obj = Expense.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "product":
                obj = Product.objects.get(id=pk, business=biz, is_deleted=True)
            else:
                return Response({"error": "Unknown record type."}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({"error": "Record not found."}, status=status.HTTP_404_NOT_FOUND)

        obj.is_deleted = False
        obj.deleted_at = None
        obj.save(update_fields=["is_deleted", "deleted_at"])
        return Response({"message": "Restored successfully."})


class RecycleBinPermanentDeleteView(APIView):
    def delete(self, request, record_type, pk):
        from sales.models import Sale
        from parties.models import Party
        from expenses.models import Expense
        from inventory.models import Product

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            if record_type == "sale":
                Sale.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "purchase":
                Purchase.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "party":
                Party.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "expense":
                Expense.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "product":
                Product.objects.get(id=pk, business=biz, is_deleted=True).delete()
            else:
                return Response({"error": "Unknown record type."}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({"error": "Record not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response(status=status.HTTP_204_NO_CONTENT)
