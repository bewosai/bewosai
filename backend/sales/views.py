import re

from django.db import IntegrityError, transaction
from rest_framework import generics, filters, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.utils import get_bid, require_business
from .models import Sale, SaleReturn, Quotation
from .serializers import SaleSerializer, SaleReturnSerializer, QuotationSerializer


class _RequirePos:
    """Gated by the Super Admin 'POS / Sales' feature switch, and by whether
    the current staff member has been granted the 'pos' module."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("pos"), require_staff_permission("sales")]


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


class SaleNextNumberView(_RequirePos, APIView):
    def get(self, request):
        business = require_business(request)
        return Response({"next_number": _next_invoice_number(business.id)})


class SaleListCreateView(_RequirePos, generics.ListCreateAPIView):
    serializer_class = SaleSerializer
    # Reports and the "load once, filter/search client-side" pages (Sales
    # list, the Topbar reminder bell) all need every matching sale, not just
    # the newest 50 — same reasoning as Inventory products/Parties, see
    # LargePageNumberPagination's docstring. Still 50 unless the caller
    # explicitly asks for more via ?page_size=.
    pagination_class = LargePageNumberPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["status", "payment_method", "customer", "reminder_enabled"]
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
        # Used by the Topbar notification bell to surface bills with money
        # still outstanding — separate from reminder_enabled, which is only
        # ever set when the user explicitly picks a reminder date/time.
        if self.request.query_params.get("has_due") in ("true", "1"):
            qs = qs.filter(due_amount__gt=0)
        return qs

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        inv = self.request.data.get("invoice_number") or _next_invoice_number(bid)
        # invoice_number is client-supplied (the app fetches "next number"
        # ahead of time so the form can show it) and only DB-unique per
        # business — a collision is a real possibility now that Sales can be
        # queued offline: two queued sales grabbing the same predicted
        # number before either syncs, or another device/staff member's sale
        # landing first. Surface it as a field error instead of silently
        # renumbering — auto-renumbering would let an offline sale sync
        # under a different invoice number than the one the user saw and
        # printed, so a collision must be resolved by hand instead.
        try:
            with transaction.atomic():
                serializer.save(business_id=bid, invoice_number=inv, created_by=self.request.user)
        except IntegrityError:
            raise ValidationError({"invoice_number": [f'Invoice number "{inv}" already exists — please update it and try again.']})


class SaleDetailView(_RequirePos, generics.RetrieveUpdateDestroyAPIView):
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


class SaleReturnListCreateView(_RequirePos, generics.ListCreateAPIView):
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


class QuotationListCreateView(_RequirePos, generics.ListCreateAPIView):
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
            is_deleted=False,
        ).select_related("customer")

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        qnum = _next_quotation_number(bid)
        serializer.save(business_id=bid, quotation_number=qnum, created_by=self.request.user)


class QuotationDetailView(_RequirePos, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = QuotationSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Quotation.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        )

    def perform_destroy(self, instance):
        from django.utils import timezone
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])
