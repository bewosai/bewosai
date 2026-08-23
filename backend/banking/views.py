from rest_framework import generics, filters, parsers, permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.utils import get_bid, require_business
from .models import BankAccount, BankTransaction
from .serializers import BankAccountSerializer, BankTransactionSerializer


class _RequireBanking:
    """Gated by the Super Admin 'Banking' feature switch, and by whether the
    current staff member has been granted the 'banking' module."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("banking"), require_staff_permission("banking")]


class BankAccountListCreateView(_RequireBanking, generics.ListCreateAPIView):
    serializer_class = BankAccountSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        bid = get_bid(self.request)
        return BankAccount.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["request"] = self.request
        return ctx

    def perform_create(self, serializer):
        serializer.save(business=require_business(self.request))


class BankAccountDetailView(_RequireBanking, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BankAccountSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        bid = get_bid(self.request)
        return BankAccount.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["request"] = self.request
        return ctx


class BankTransactionListCreateView(_RequireBanking, generics.ListCreateAPIView):
    serializer_class = BankTransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["transaction_type", "account"]
    ordering_fields = ["date", "amount"]

    def get_queryset(self):
        bid = get_bid(self.request)
        qs = BankTransaction.objects.filter(
            account__business_id=bid,
            account__business__staff__user=self.request.user,
            account__business__staff__is_active=True,
        ).select_related("account", "created_by")
        account_id = self.request.query_params.get("account")
        if account_id:
            qs = qs.filter(account_id=account_id)
        return qs

    def perform_create(self, serializer):
        business = require_business(self.request)
        account = serializer.validated_data.get("account")
        if account is None or account.business_id != business.id:
            raise ValidationError({"account": "Invalid account for this business."})
        serializer.save(created_by=self.request.user)


class BankTransactionDetailView(_RequireBanking, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BankTransactionSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return BankTransaction.objects.filter(
            account__business_id=bid,
            account__business__staff__user=self.request.user,
            account__business__staff__is_active=True,
        )

    def perform_update(self, serializer):
        business = require_business(self.request)
        account = serializer.validated_data.get("account")
        if account is not None and account.business_id != business.id:
            raise ValidationError({"account": "Invalid account for this business."})
        serializer.save()

    # Sales/Purchases/Payments each keep a mirrored BankTransaction in sync
    # (see bewosai.utils.sync_bank_transaction) via a "SALE-<id>" / "PURCHASE-
    # <id>" / "PARTYPAYMENT-<id>" reference. Deleting that mirror directly
    # from here would desync the bank balance from the source record's own
    # paid_amount (which only the source's own delete/edit flow keeps
    # correct) — point the user at the source instead.
    _MIRROR_PREFIXES = ("SALE-", "PURCHASE-", "PARTYPAYMENT-")
    _MIRROR_SOURCE_LABEL = {"SALE-": "Sales", "PURCHASE-": "Purchases", "PARTYPAYMENT-": "Payments"}

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        prefix = next((p for p in self._MIRROR_PREFIXES if instance.reference.startswith(p)), None)
        if prefix:
            return Response(
                {"error": f"This transaction is linked to a record in {self._MIRROR_SOURCE_LABEL[prefix]} — delete or edit it from there instead."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().destroy(request, *args, **kwargs)
