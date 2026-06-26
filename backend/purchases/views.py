from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from accounts.models import Business
from .models import Purchase, PurchaseReturn
from .serializers import PurchaseSerializer, PurchaseReturnSerializer


def get_business(request):
    bid = request.headers.get("X-Business-ID") or request.query_params.get("business_id")
    return Business.objects.filter(id=bid, staff__user=request.user, staff__is_active=True).first()


class PurchaseListCreateView(generics.ListCreateAPIView):
    serializer_class = PurchaseSerializer

    def get_queryset(self):
        biz = get_business(self.request)
        if not biz:
            return Purchase.objects.none()
        qs = Purchase.objects.filter(business=biz, is_deleted=False)
        supplier = self.request.query_params.get("supplier")
        if supplier:
            qs = qs.filter(supplier_id=supplier)
        return qs

    def perform_create(self, serializer):
        biz = get_business(self.request)
        # Auto bill number
        last = Purchase.objects.filter(business=biz).order_by("-id").first()
        try:
            num = int(last.bill_number.split("-")[-1]) + 1 if last else 1
        except (ValueError, AttributeError):
            num = Purchase.objects.filter(business=biz).count() + 1
        bill_number = f"PUR-{num:04d}"
        serializer.save(business=biz, bill_number=bill_number, created_by=self.request.user)


class PurchaseDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PurchaseSerializer

    def get_queryset(self):
        biz = get_business(self.request)
        return Purchase.objects.filter(business=biz, is_deleted=False)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save()


class RecycleBinView(APIView):
    """Lists all soft-deleted records across models."""
    def get(self, request):
        from sales.models import Sale
        from parties.models import Party
        biz = get_business(request)
        if not biz:
            return Response([])

        result = []
        for sale in Sale.objects.filter(business=biz, is_deleted=True):
            result.append({"type": "sale", "id": sale.id, "label": sale.invoice_number, "deleted_at": sale.deleted_at})
        for purchase in Purchase.objects.filter(business=biz, is_deleted=True):
            result.append({"type": "purchase", "id": purchase.id, "label": purchase.bill_number, "deleted_at": purchase.deleted_at})
        for party in Party.objects.filter(business=biz, is_deleted=True):
            result.append({"type": "party", "id": party.id, "label": party.name, "deleted_at": party.deleted_at})

        result.sort(key=lambda x: x["deleted_at"] or timezone.now(), reverse=True)
        return Response(result)


class RecycleBinRestoreView(APIView):
    def post(self, request, record_type, pk):
        biz = get_business(request)
        if record_type == "sale":
            from sales.models import Sale
            obj = Sale.objects.get(id=pk, business=biz)
        elif record_type == "purchase":
            obj = Purchase.objects.get(id=pk, business=biz)
        elif record_type == "party":
            from parties.models import Party
            obj = Party.objects.get(id=pk, business=biz)
        else:
            return Response({"error": "Unknown type"}, status=400)
        obj.is_deleted = False
        obj.deleted_at = None
        obj.save()
        return Response({"message": "Restored"})


class RecycleBinPermanentDeleteView(APIView):
    def delete(self, request, record_type, pk):
        biz = get_business(request)
        if record_type == "sale":
            from sales.models import Sale
            Sale.objects.get(id=pk, business=biz, is_deleted=True).delete()
        elif record_type == "purchase":
            Purchase.objects.get(id=pk, business=biz, is_deleted=True).delete()
        elif record_type == "party":
            from parties.models import Party
            Party.objects.get(id=pk, business=biz, is_deleted=True).delete()
        else:
            return Response({"error": "Unknown type"}, status=400)
        return Response(status=204)
