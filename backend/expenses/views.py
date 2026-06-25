from rest_framework import generics, filters
from django_filters.rest_framework import DjangoFilterBackend
from .models import ExpenseCategory, Expense
from .serializers import ExpenseCategorySerializer, ExpenseSerializer


class ExpenseCategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = ExpenseCategorySerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return ExpenseCategory.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class ExpenseListCreateView(generics.ListCreateAPIView):
    serializer_class = ExpenseSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["category", "payment_method"]
    ordering_fields = ["date", "amount", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = Expense.objects.filter(business_id=bid, business__staff__user=self.request.user)
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid, created_by=self.request.user)


class ExpenseDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ExpenseSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Expense.objects.filter(business_id=bid, business__staff__user=self.request.user)
