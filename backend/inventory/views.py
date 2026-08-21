from rest_framework import generics, filters, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import F

from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, IsPremiumBusiness, require_feature
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
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("inventory")]


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
    """Bulk create products from Excel import. Accepts list of product objects. Premium only."""

    permission_classes = [IsPremiumBusiness, HasActiveSubscription, require_feature("excel_import")]

    MAX_ROWS = 500

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

        # Case-insensitive so re-uploading the same file (or a file that
        # overlaps an earlier import) doesn't silently create duplicate
        # products — Product has no DB-level unique constraint on name, so
        # without this check every re-run would double up the catalog.
        existing_names = {
            n.lower() for n in Product.objects.filter(business_id=bid, is_deleted=False).values_list("name", flat=True)
        }
        seen_in_file = set()

        created, skipped = [], []
        for row in rows:
            name = (row.get("name") or "").strip()
            if not name:
                skipped.append({"row": row, "reason": "Missing name"})
                continue
            key = name.lower()
            if key in existing_names:
                skipped.append({"row": row, "reason": f'A product named "{name}" already exists'})
                continue
            if key in seen_in_file:
                skipped.append({"row": row, "reason": f'Duplicate "{name}" elsewhere in this file'})
                continue
            seen_in_file.add(key)
            try:
                threshold = row.get("low_stock_threshold")
                category_name = (row.get("category") or "").strip()
                category = (
                    Category.objects.get_or_create(business_id=bid, name=category_name)[0]
                    if category_name else None
                )
                unit_name = (row.get("unit") or "").strip()
                unit = (
                    Unit.objects.get_or_create(business_id=bid, name=unit_name)[0]
                    if unit_name else None
                )
                product = Product.objects.create(
                    business_id=bid,
                    name=name,
                    category=category,
                    unit=unit,
                    sale_price=row.get("sale_price") or 0,
                    purchase_price=row.get("purchase_price") or 0,
                    stock_quantity=row.get("stock_quantity") or 0,
                    low_stock_threshold=5 if threshold in (None, "") else threshold,
                    barcode=row.get("barcode") or "",
                    hs_code=row.get("hs_code") or "",
                    description=row.get("description") or "",
                )
                created.append(product.id)
            except Exception as e:
                skipped.append({"row": row, "reason": str(e)})

        return Response({"created": len(created), "skipped": len(skipped), "skipped_details": skipped})
