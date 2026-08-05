from rest_framework import generics, filters, parsers
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.utils import get_bid, require_business
from .models import BankAccount, BankTransaction
from .serializers import BankAccountSerializer, BankTransactionSerializer


class BankAccountListCreateView(generics.ListCreateAPIView):
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


class BankAccountDetailView(generics.RetrieveUpdateDestroyAPIView):
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


class BankTransactionListCreateView(generics.ListCreateAPIView):
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


class BankTransactionDetailView(generics.RetrieveUpdateDestroyAPIView):
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
