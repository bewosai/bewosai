import re

from django.db import IntegrityError, transaction
from django.db.models import Prefetch
from django.utils import timezone
from rest_framework import generics, filters, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, FiscalYearLocked, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.locking import LockedWritesMixin, lock
from bewosai.utils import get_bid, require_business
from inventory import stock
from parties.allocations import release_allocations
from .models import Sale, SaleItem, SaleReturn, Quotation
from .serializers import SaleSerializer, SaleReturnSerializer, QuotationSerializer


class _RequirePos:
    """Gated by the Super Admin 'POS / Sales' feature switch, and by whether
    the current staff member has been granted the 'pos' module."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("pos"), require_staff_permission("sales"), FiscalYearLocked]


def _next_invoice_number(business_id):
    """The business's invoice prefix (Settings → Invoice; "INV-" by default)
    followed by the number after its latest invoice's."""
    from accounts.models import Business

    settings_ = Business.objects.filter(pk=business_id).values_list("invoice_settings", flat=True).first() or {}
    prefix = settings_.get("invoice_prefix") or "INV-"
    last = Sale.objects.filter(business_id=business_id).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.invoice_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    number = f"{prefix}{num:04d}"
    # A prefix change can collide with an older invoice; step past any that exist.
    while Sale.objects.filter(business_id=business_id, invoice_number=number).exists():
        num += 1
        number = f"{prefix}{num:04d}"
    return number


def _next_quotation_number(business_id):
    last = Quotation.objects.filter(business_id=business_id).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.quotation_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    number = f"QUO-{num:04d}"
    # Never hand out a number another quotation of this business already has.
    while Quotation.objects.filter(business_id=business_id, quotation_number__iexact=number).exists():
        num += 1
        number = f"QUO-{num:04d}"
    return number


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
        ).select_related("customer", "created_by").prefetch_related(
            # Every sale's items (and each item's product + unit) in one query,
            # not one query per sale plus two per line item.
            Prefetch("items", queryset=SaleItem.objects.select_related("product__unit")),
        )
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
        # The checked, space-trimmed number (see SaleSerializer.validate_invoice_number).
        inv = serializer.validated_data.get("invoice_number") or _next_invoice_number(bid)
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


class SaleDetailView(LockedWritesMixin, _RequirePos, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SaleSerializer
    fiscal_lock_date_field = "sale_date"
    fiscal_lock_business_field = "business"

    def get_queryset(self):
        bid = get_bid(self.request)
        return Sale.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        ).select_related("customer")

    def perform_update(self, serializer):
        # Cancelling an invoice: later repayments applied to it go back to the
        # customer as credit instead of vanishing with it (see parties.allocations).
        was_confirmed = serializer.instance.status == Sale.STATUS_CONFIRMED
        with transaction.atomic():
            sale = serializer.save()
            if was_confirmed and sale.status != Sale.STATUS_CONFIRMED:
                release_allocations(sale=sale)

    def perform_destroy(self, instance):
        from django.utils import timezone
        with transaction.atomic():
            release_allocations(sale=instance)
            if instance.status == Sale.STATUS_CONFIRMED:
                stock.undo_sale(instance.items.all())
            instance.is_deleted = True
            instance.deleted_at = timezone.now()
            instance.save(update_fields=["is_deleted", "deleted_at"])
            SaleSerializer._sync_bank(instance)


class SaleReturnListCreateView(_RequirePos, generics.ListCreateAPIView):
    serializer_class = SaleReturnSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return SaleReturn.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def create(self, request, *args, **kwargs):
        # The original invoice stays locked while the "not more than was sold"
        # check runs and the return is saved, so two returns at once can't
        # both pass it.
        with transaction.atomic():
            original = str(request.data.get("original_sale") or "")
            if original.isdigit():
                lock(Sale.objects.filter(pk=original, business_id=get_bid(request))).first()
            return super().create(request, *args, **kwargs)

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
        # Two quotations created at the same moment are numbered one at a time
        # (the business row is the lock), so they can't both get the same number.
        from accounts.models import Business
        with transaction.atomic():
            lock(Business.objects.filter(pk=bid)).first()
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


class SaleReceivePaymentView(APIView):
    """Receive (part of) what's still due on one invoice — a repayment.

    Recorded as a normal party payment from the invoice's customer, so it shows
    in their ledger, the day book, cash/bank and the Payments list like any
    other; but it settles *this* invoice rather than their oldest one. At most
    the invoice's due amount; the invoice needs a customer to record it against.
    """

    permission_classes = [
        permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription,
        require_feature("payments"), require_staff_permission("payments"),
    ]

    def post(self, request, pk):
        # The invoice stays locked from reading what's due to recording the
        # payment: a double-tapped "Receive" (or two staff at once) must not
        # both see the same amount due and pay it twice.
        with transaction.atomic():
            response = self._receive(request, pk)
            if response.status_code >= 400:
                transaction.set_rollback(True)
            return response

    def _receive(self, request, pk):
        from decimal import Decimal, InvalidOperation
        from parties.serializers import PartyPaymentSerializer
        from parties.views import PartyPaymentListCreateView

        def refuse(message):
            return Response({"message": message}, status=400)

        sale = lock(Sale.objects.filter(
            pk=pk, business_id=get_bid(request), business__staff__user=request.user,
            business__staff__is_active=True, is_deleted=False,
        )).first()
        if sale is None:
            return Response({"message": "Invoice not found."}, status=404)
        if sale.status != Sale.STATUS_CONFIRMED:
            return refuse("Only a confirmed invoice can receive payments.")
        if sale.customer_id is None:
            return refuse("This invoice has no customer — edit it to add one, then record the payment.")
        try:
            amount = Decimal(str(request.data.get("amount", "")).replace(",", "").strip())
        except InvalidOperation:
            return refuse("Enter the amount received.")
        if not amount.is_finite() or amount <= 0:
            return refuse("Enter an amount above 0.")
        if amount > sale.due_amount + Decimal("0.005"):
            return refuse(f"Only Rs {sale.due_amount} is due on invoice {sale.invoice_number}.")

        serializer = PartyPaymentSerializer(data={
            "party": sale.customer_id,
            "payment_type": "IN",
            "amount": str(amount),
            "payment_method": request.data.get("payment_method") or "CASH",
            "bank_account": request.data.get("bank_account") or None,
            "date": request.data.get("date") or timezone.localdate().isoformat(),
            "note": request.data.get("note") or f"Payment for invoice {sale.invoice_number}",
        }, context={"request": request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)
        payment = serializer.save(created_by=request.user)
        PartyPaymentListCreateView._reconcile_payment(payment, first_sale=sale)
        PartyPaymentSerializer._sync_bank(payment)
        sale.refresh_from_db()
        return Response({
            "message": f"Rs {amount} received for invoice {sale.invoice_number}. Still due: Rs {sale.due_amount}.",
            "payment_id": payment.id,
            "paid_amount": sale.paid_amount,
            "due_amount": sale.due_amount,
        }, status=201)
