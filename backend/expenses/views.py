from rest_framework import generics, filters, parsers, permissions
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, FiscalYearLocked, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.utils import get_bid, require_business
from .models import ExpenseCategory, Expense
from .serializers import ExpenseCategorySerializer, ExpenseSerializer


class _RequireExpenses:
    """Gated by the Super Admin 'Expenses' feature switch, and by whether the
    current staff member has been granted the 'expenses' module."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("expenses"), require_staff_permission("expenses"), FiscalYearLocked]


class ExpenseCategoryListCreateView(_RequireExpenses, generics.ListCreateAPIView):
    serializer_class = ExpenseCategorySerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return ExpenseCategory.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def perform_create(self, serializer):
        serializer.save(business=require_business(self.request))


class ExpenseListCreateView(_RequireExpenses, generics.ListCreateAPIView):
    serializer_class = ExpenseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["category", "payment_method"]
    ordering_fields = ["date", "amount", "created_at"]
    # See the matching comment on sales.SaleListCreateView — Reports and the
    # Expenses list both need every matching expense, not just the newest 50.
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        bid = get_bid(self.request)
        qs = Expense.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        )
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        business = require_business(self.request)
        category = serializer.validated_data.get("category")
        if category is not None and category.business_id != business.id:
            raise ValidationError({"category": "Invalid category for this business."})
        serializer.save(business=business, created_by=self.request.user)


class ExpenseDetailView(_RequireExpenses, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ExpenseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]
    fiscal_lock_date_field = "date"
    fiscal_lock_business_field = "business"

    def get_queryset(self):
        bid = get_bid(self.request)
        return Expense.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        )

    def perform_update(self, serializer):
        business = require_business(self.request)
        category = serializer.validated_data.get("category")
        if category is not None and category.business_id != business.id:
            raise ValidationError({"category": "Invalid category for this business."})
        serializer.save()

    def perform_destroy(self, instance):
        from django.utils import timezone
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])
