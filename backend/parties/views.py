from rest_framework import generics, filters
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum
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
        return Party.objects.filter(business_id=bid, is_deleted=False)

    def perform_create(self, serializer):
        bid = self.request.data.get("business")
        serializer.save(business_id=bid)


class PartyDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PartySerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return Party.objects.filter(business_id=bid, is_deleted=False)


class PartyPaymentListCreateView(generics.ListCreateAPIView):
    serializer_class = PartyPaymentSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["payment_type", "payment_method"]
    ordering_fields = ["date", "created_at"]

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        qs = PartyPayment.objects.filter(party__business_id=bid)
        party_id = self.request.query_params.get("party")
        if party_id:
            qs = qs.filter(party_id=party_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class PartyPaymentDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = PartyPaymentSerializer

    def get_queryset(self):
        bid = self.request.query_params.get("business")
        return PartyPayment.objects.filter(party__business_id=bid)


class PartyLedgerView(APIView):
    """Returns a combined ledger for a party: sales, purchases, and direct payments."""

    def get(self, request, pk):
        bid = request.query_params.get("business")
        try:
            party = Party.objects.get(pk=pk, business_id=bid, is_deleted=False)
        except Party.DoesNotExist:
            return Response({"error": "Party not found"}, status=404)

        from sales.models import Sale
        from purchases.models import Purchase

        entries = []

        # Sales (customer invoices)
        for s in Sale.objects.filter(customer=party, is_deleted=False).order_by("sale_date"):
            entries.append({
                "date": str(s.sale_date),
                "type": "SALE",
                "ref": s.invoice_number,
                "debit": float(s.total),
                "credit": 0,
                "balance": 0,
                "note": s.notes or "",
            })
            if s.paid_amount > 0:
                entries.append({
                    "date": str(s.sale_date),
                    "type": "RECEIPT",
                    "ref": s.invoice_number,
                    "debit": 0,
                    "credit": float(s.paid_amount),
                    "balance": 0,
                    "note": f"Payment via {s.payment_method}",
                })

        # Purchases (supplier bills)
        for p in Purchase.objects.filter(supplier=party, is_deleted=False).order_by("purchase_date"):
            entries.append({
                "date": str(p.purchase_date),
                "type": "PURCHASE",
                "ref": p.bill_number,
                "debit": 0,
                "credit": float(p.total),
                "balance": 0,
                "note": p.notes or "",
            })
            if p.paid_amount > 0:
                entries.append({
                    "date": str(p.purchase_date),
                    "type": "PAYMENT",
                    "ref": p.bill_number,
                    "debit": float(p.paid_amount),
                    "credit": 0,
                    "balance": 0,
                    "note": f"Payment via {p.payment_method}",
                })

        # Direct payments
        for pay in PartyPayment.objects.filter(party=party).order_by("date"):
            entries.append({
                "date": str(pay.date),
                "type": "PAYMENT_IN" if pay.payment_type == "IN" else "PAYMENT_OUT",
                "ref": f"PMT-{pay.id}",
                "debit": float(pay.amount) if pay.payment_type == "OUT" else 0,
                "credit": float(pay.amount) if pay.payment_type == "IN" else 0,
                "balance": 0,
                "note": pay.note or "",
            })

        # Sort by date, calculate running balance
        entries.sort(key=lambda x: x["date"])
        balance = float(party.opening_balance)
        for e in entries:
            balance += e["debit"] - e["credit"]
            e["balance"] = round(balance, 2)

        # Summary
        total_debit = sum(e["debit"] for e in entries)
        total_credit = sum(e["credit"] for e in entries)

        return Response({
            "party": PartySerializer(party).data,
            "opening_balance": float(party.opening_balance),
            "entries": entries,
            "total_debit": round(total_debit, 2),
            "total_credit": round(total_credit, 2),
            "closing_balance": round(float(party.opening_balance) + total_debit - total_credit, 2),
        })
