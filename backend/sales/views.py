from rest_framework import generics, filters, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum
from .models import Sale, SaleReturn, Quotation
from .serializers import SaleSerializer, SaleReturnSerializer, QuotationSerializer
import re
from datetime import date


def next_invoice_number(business_id):
    last = Sale.objects.filter(business_id=business_id).order_by("-created_at").first()
    if last:
        match = re.search(r"(\d+)$", last.invoice_number)
        num = int(match.group(1)) + 1 if match else 1
    else:
        num = 1
    return f"INV-{num:04d}"


class SaleListCreateView(generics.ListCreateAPIView):
    serializer_class = SaleSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["status", "payment_method", "customer"]
    search_fields = ["invoice_number", "customer__name"]
    ordering_fields = ["sale_date", "total", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = Sale.objects.filter(business_id=bid, business__staff__user=self.request.user, is_deleted=False)
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(sale_date__gte=date_from)
        if date_to:
            qs = qs.filter(sale_date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        inv = self.request.data.get("invoice_number") or next_invoice_number(bid)
        serializer.save(business_id=bid, invoice_number=inv, created_by=self.request.user)


class SaleDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SaleSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Sale.objects.filter(business_id=bid, business__staff__user=self.request.user)


class SaleReturnListCreateView(generics.ListCreateAPIView):
    serializer_class = SaleReturnSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return SaleReturn.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid, created_by=self.request.user)


class QuotationListCreateView(generics.ListCreateAPIView):
    serializer_class = QuotationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ["status"]
    search_fields = ["quotation_number", "customer__name"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Quotation.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        last = Quotation.objects.filter(business_id=bid).count() + 1
        qnum = f"QUO-{last:04d}"
        serializer.save(business_id=bid, quotation_number=qnum, created_by=self.request.user)


class QuotationDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = QuotationSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Quotation.objects.filter(business_id=bid, business__staff__user=self.request.user)
