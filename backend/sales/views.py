import re

from rest_framework import generics, filters
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.utils import get_bid, require_business
from .models import Sale, SaleReturn, Quotation
from .serializers import SaleSerializer, SaleReturnSerializer, QuotationSerializer


def _next_invoice_number(business_id):
    last = Sale.objects.filter(business_id=business_id).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.invoice_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    return f"INV-{num:04d}"


def _next_quotation_number(business_id):
    last = Quotation.objects.filter(business_id=business_id).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.quotation_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    return f"QUO-{num:04d}"


class SaleNextNumberView(APIView):
    def get(self, request):
        business = require_business(request)
        return Response({"next_number": _next_invoice_number(business.id)})


class SaleListCreateView(generics.ListCreateAPIView):
    serializer_class = SaleSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["status", "payment_method", "customer"]
    search_fields = ["invoice_number", "customer__name"]
    ordering_fields = ["sale_date", "total", "created_at"]

    def get_queryset(self):
        bid = get_bid(self.request)
        qs = Sale.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        ).select_related("customer", "created_by")
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(sale_date__gte=date_from)
        if date_to:
            qs = qs.filter(sale_date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        inv = self.request.data.get("invoice_number") or _next_invoice_number(bid)
        serializer.save(
            business_id=bid,
            invoice_number=inv,
            created_by=self.request.user,
        )


class SaleDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SaleSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Sale.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        ).select_related("customer")

    def perform_destroy(self, instance):
        from django.utils import timezone
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])


class SaleReturnListCreateView(generics.ListCreateAPIView):
    serializer_class = SaleReturnSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return SaleReturn.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        serializer.save(business_id=bid, created_by=self.request.user)


class QuotationListCreateView(generics.ListCreateAPIView):
    serializer_class = QuotationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ["status"]
    search_fields = ["quotation_number", "customer__name"]

    def get_queryset(self):
        bid = get_bid(self.request)
        return Quotation.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        ).select_related("customer")

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        qnum = _next_quotation_number(bid)
        serializer.save(business_id=bid, quotation_number=qnum, created_by=self.request.user)


class QuotationDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = QuotationSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Quotation.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )
