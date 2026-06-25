from rest_framework import generics, filters, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from .models import Category, Unit, Product, StockMovement
from .serializers import CategorySerializer, UnitSerializer, ProductSerializer, StockMovementSerializer
from accounts.models import Business


def get_business(request):
    bid = request.query_params.get("business") or request.data.get("business")
    return Business.objects.filter(id=bid, staff__user=request.user, staff__is_active=True).first()


class CategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = CategorySerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ["name"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Category.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Category.objects.filter(business_id=bid, business__staff__user=self.request.user)


class UnitListCreateView(generics.ListCreateAPIView):
    serializer_class = UnitSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Unit.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class UnitDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UnitSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Unit.objects.filter(business_id=bid, business__staff__user=self.request.user)


class ProductListCreateView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["category", "is_active"]
    search_fields = ["name", "barcode"]
    ordering_fields = ["name", "stock_quantity", "sale_price", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = Product.objects.filter(business_id=bid, business__staff__user=self.request.user)
        if self.request.query_params.get("low_stock"):
            from django.db.models import F
            qs = qs.filter(stock_quantity__lte=F("low_stock_threshold"))
        return qs

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Product.objects.filter(business_id=bid, business__staff__user=self.request.user)


class StockMovementListCreateView(generics.ListCreateAPIView):
    serializer_class = StockMovementSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["movement_type", "product"]
    ordering_fields = ["created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return StockMovement.objects.filter(
            product__business_id=bid,
            product__business__staff__user=self.request.user,
        )

    def perform_create(self, serializer):
        movement = serializer.save(created_by=self.request.user)
        product = movement.product
        if movement.movement_type == StockMovement.STOCK_IN:
            product.stock_quantity += movement.quantity
        elif movement.movement_type == StockMovement.STOCK_OUT:
            product.stock_quantity -= movement.quantity
        else:
            product.stock_quantity = movement.quantity
        product.save(update_fields=["stock_quantity"])
