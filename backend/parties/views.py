from rest_framework import generics, filters
from django_filters.rest_framework import DjangoFilterBackend
from .models import Party, PartyPayment
from .serializers import PartySerializer, PartyPaymentSerializer


class PartyListCreateView(generics.ListCreateAPIView):
    serializer_class = PartySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["party_type", "is_active"]
    search_fields = ["name", "phone", "email"]
    ordering_fields = ["name", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Party.objects.filter(business_id=bid, business__staff__user=self.request.user)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class PartyDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PartySerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Party.objects.filter(business_id=bid, business__staff__user=self.request.user)


class PartyPaymentListCreateView(generics.ListCreateAPIView):
    serializer_class = PartyPaymentSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["payment_type", "payment_method"]
    ordering_fields = ["date", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = PartyPayment.objects.filter(party__business_id=bid, party__business__staff__user=self.request.user)
        party_id = self.request.query_params.get("party")
        if party_id:
            qs = qs.filter(party_id=party_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
