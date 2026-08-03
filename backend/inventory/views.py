from rest_framework import generics, filters, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import F

from bewosy.permissions import IsPremiumBusiness
from bewosy.utils import get_bid
from .models import Category, Unit, Product, StockMovement
from .serializers import CategorySerializer, UnitSerializer, ProductSerializer, StockMovementSerializer


class CategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = CategorySerializer
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
        bid = get_bid(self.request)
        serializer.save(business_id=bid)


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Category.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )


class UnitListCreateView(generics.ListCreateAPIView):
    serializer_class = UnitSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Unit.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        serializer.save(business_id=bid)


class UnitDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UnitSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Unit.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
        )


class ProductListCreateView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
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
        )
        if self.request.query_params.get("low_stock"):
            qs = qs.filter(stock_quantity__lte=F("low_stock_threshold"))
        return qs

    def perform_create(self, serializer):
        bid = get_bid(self.request)
        serializer.save(business_id=bid)


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Product.objects.filter(
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


class StockMovementListCreateView(generics.ListCreateAPIView):
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
        movement = serializer.save(created_by=self.request.user)
        product = movement.product
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

    permission_classes = [IsPremiumBusiness]

    def post(self, request):
        bid = get_bid(request)
        if not bid:
            return Response({"error": "No business selected."}, status=status.HTTP_400_BAD_REQUEST)
        rows = request.data.get("products", [])
        if not isinstance(rows, list):
            return Response({"error": "Expected 'products' list."}, status=status.HTTP_400_BAD_REQUEST)

        created, skipped = [], []
        for row in rows:
            name = (row.get("name") or "").strip()
            if not name:
                skipped.append({"row": row, "reason": "Missing name"})
                continue
            try:
                product = Product.objects.create(
                    business_id=bid,
                    name=name,
                    sale_price=row.get("sale_price") or 0,
                    purchase_price=row.get("purchase_price") or 0,
                    stock_quantity=row.get("stock_quantity") or 0,
                    low_stock_threshold=row.get("low_stock_threshold") or 5,
                    barcode=row.get("barcode") or "",
                    description=row.get("description") or "",
                )
                created.append(product.id)
            except Exception as e:
                skipped.append({"row": row, "reason": str(e)})

        return Response({"created": len(created), "skipped": len(skipped), "skipped_details": skipped})

    def perform_create(self, serializer):
        movement = serializer.save(created_by=self.request.user)
        product = movement.product
        mt = movement.movement_type

        if mt == StockMovement.STOCK_IN or mt == StockMovement.OPENING:
            product.stock_quantity = product.stock_quantity + movement.quantity
        elif mt == StockMovement.STOCK_OUT:
            product.stock_quantity = max(0, product.stock_quantity - movement.quantity)
        elif mt in (StockMovement.DAMAGE, StockMovement.LOST, StockMovement.TRANSFER):
            product.stock_quantity = max(0, product.stock_quantity - movement.quantity)
        elif mt == StockMovement.ADJUSTMENT:
            # Absolute adjustment — sets stock to the specified quantity
            product.stock_quantity = movement.quantity

        product.save(update_fields=["stock_quantity"])
