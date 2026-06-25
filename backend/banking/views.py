from rest_framework import generics, filters
from django_filters.rest_framework import DjangoFilterBackend
from .models import BankAccount, BankTransaction
from .serializers import BankAccountSerializer, BankTransactionSerializer


class BankAccountListCreateView(generics.ListCreateAPIView):
    serializer_class = BankAccountSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return BankAccount.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class BankAccountDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BankAccountSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return BankAccount.objects.filter(business_id=bid, business__staff__user=self.request.user)


class BankTransactionListCreateView(generics.ListCreateAPIView):
    serializer_class = BankTransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["transaction_type", "account"]
    ordering_fields = ["date", "amount"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = BankTransaction.objects.filter(
            account__business_id=bid,
            account__business__staff__user=self.request.user,
        )
        account_id = self.request.query_params.get("account")
        if account_id:
            qs = qs.filter(account_id=account_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
