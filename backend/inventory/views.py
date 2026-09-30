from decimal import Decimal

from rest_framework import generics, filters, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import F

from bewosai import bulk_import
from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, IsPremiumBusiness, require_feature, require_staff_permission
from bewosai.utils import get_bid, require_business
from .models import Category, Unit, Product, StockMovement
from .serializers import CategorySerializer, UnitSerializer, ProductSerializer, StockMovementSerializer


def _validate_category_unit(validated_data, business):
    category = validated_data.get("category")
    if category is not None and category.business_id != business.id:
        raise ValidationError({"category": "Invalid category for this business."})
    unit = validated_data.get("unit")
    if unit is not None and unit.business_id != business.id:
        raise ValidationError({"unit": "Invalid unit for this business."})


class _RequireInventory:
    """Gated by the Super Admin 'Inventory' feature switch."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("inventory"), require_staff_permission("inventory")]


class CategoryListCreateView(_RequireInventory, generics.ListCreateAPIView):
    serializer_class = CategorySerializer
    pagination_class = LargePageNumberPagination
    filter_backends = [filters.SearchFilter]
    search_fields = ["name"]

    def get_queryset(self):
        bid = get_bid(self.request)
        return Category.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def perform_create(self, serializer):
        serializer.save(business=require_business(self.request))


class CategoryDetailView(_RequireInventory, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Category.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )


class UnitListCreateView(_RequireInventory, generics.ListCreateAPIView):
    serializer_class = UnitSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        bid = get_bid(self.request)
        return Unit.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def perform_create(self, serializer):
        serializer.save(business=require_business(self.request))


class UnitDetailView(_RequireInventory, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UnitSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Unit.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )


class ProductListCreateView(_RequireInventory, generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    pagination_class = LargePageNumberPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["category", "is_active"]
    search_fields = ["name", "barcode"]
    ordering_fields = ["name", "stock_quantity", "sale_price", "created_at"]

    def get_queryset(self):
        bid = get_bid(self.request)
        qs = Product.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        ).select_related("category", "unit")
        if self.request.query_params.get("low_stock"):
            qs = qs.filter(stock_quantity__lte=F("low_stock_threshold"))
        return qs

    def perform_create(self, serializer):
        business = require_business(self.request)
        _validate_category_unit(serializer.validated_data, business)
        serializer.save(business=business)


class ProductDetailView(_RequireInventory, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Product.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        ).select_related("category", "unit")

    def perform_update(self, serializer):
        business = require_business(self.request)
        _validate_category_unit(serializer.validated_data, business)
        serializer.save()

    def perform_destroy(self, instance):
        from django.utils import timezone
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])


class StockMovementListCreateView(_RequireInventory, generics.ListCreateAPIView):
    serializer_class = StockMovementSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["movement_type", "product"]
    ordering_fields = ["created_at"]

    def get_queryset(self):
        bid = get_bid(self.request)
        return StockMovement.objects.filter(
            product__business_id=bid,
            product__business__staff__user=self.request.user,
            product__business__staff__is_active=True,
        ).select_related("product", "created_by")

    def perform_create(self, serializer):
        business = require_business(self.request)
        product = serializer.validated_data.get("product")
        if product is None or product.business_id != business.id:
            raise ValidationError({"product": "Invalid product for this business."})

        movement = serializer.save(created_by=self.request.user)
        mt = movement.movement_type

        if mt in (StockMovement.STOCK_IN, StockMovement.OPENING):
            product.stock_quantity = product.stock_quantity + movement.quantity
        elif mt == StockMovement.STOCK_OUT:
            product.stock_quantity = max(0, product.stock_quantity - movement.quantity)
        elif mt in (StockMovement.DAMAGE, StockMovement.LOST, StockMovement.TRANSFER):
            product.stock_quantity = max(0, product.stock_quantity - movement.quantity)
        elif mt == StockMovement.ADJUSTMENT:
            product.stock_quantity = movement.quantity  # absolute set

        product.save(update_fields=["stock_quantity"])


class ProductBulkImportView(APIView):
    """Bulk create products from an Excel import (Premium). Each row is checked
    on its own — see bewosai.bulk_import. Send "dry_run": true to get the
    per-row Ready / Will-skip preview without saving anything."""

    permission_classes = [IsPremiumBusiness, HasActiveSubscription, require_feature("excel_import"), require_staff_permission("inventory")]

    MAX_ROWS = bulk_import.MAX_ROWS

    def post(self, request):
        bid = get_bid(request)
        if not bid:
            return Response({"error": "No business selected."}, status=status.HTTP_400_BAD_REQUEST)
        rows = request.data.get("products", [])
        if not isinstance(rows, list):
            return Response({"error": "Expected 'products' list."}, status=status.HTTP_400_BAD_REQUEST)
        if len(rows) > self.MAX_ROWS:
            return Response(
                {"error": f"Import is limited to {self.MAX_ROWS} rows at a time — this file has {len(rows)}. Split it into smaller files and import each separately."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Case-insensitive, so re-uploading the same file (or one overlapping an
        # earlier import) can't double up the catalog — Product has no DB-level
        # unique constraint on name.
        existing = {
            n.lower() for n in Product.objects.filter(business_id=bid, is_deleted=False).values_list("name", flat=True)
        }

        def clean(row):
            threshold = bulk_import.amount(row, "low_stock_threshold", "Low stock alert", default=Decimal("5"))
            return {
                "category_name": str(row.get("category") or "").strip(),
                "unit_name": str(row.get("unit") or "").strip(),
                "sale_price": bulk_import.amount(row, "sale_price", "Sale price"),
                "purchase_price": bulk_import.amount(row, "purchase_price", "Purchase price"),
                "secondary_sale_price": bulk_import.amount(
                    row, "secondary_sale_price", "Sale price per secondary unit", blank_is_none=True),
                "secondary_purchase_price": bulk_import.amount(
                    row, "secondary_purchase_price", "Purchase price per secondary unit", blank_is_none=True),
                "stock_quantity": bulk_import.amount(row, "stock_quantity", "Stock quantity"),
                "low_stock_threshold": threshold,
                "barcode": str(row.get("barcode") or "").strip(),
                "hs_code": str(row.get("hs_code") or "").strip(),
                "description": str(row.get("description") or "").strip(),
            }

        def create(c):
            category_name, unit_name = c.pop("category_name"), c.pop("unit_name")
            category = Category.objects.get_or_create(business_id=bid, name=category_name)[0] if category_name else None
            unit = Unit.objects.get_or_create(business_id=bid, name=unit_name)[0] if unit_name else None
            Product.objects.create(business_id=bid, category=category, unit=unit, **c)

        return Response(bulk_import.run(
            rows, existing_names=existing, noun="product", clean=clean, create=create,
            dry_run=bool(request.data.get("dry_run")),
        ))
