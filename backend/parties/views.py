from decimal import Decimal
from rest_framework import generics, filters, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend

from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, IsPremiumBusiness, require_feature
from bewosai.utils import get_bid, get_business
from .models import Party, PartyPayment
from .serializers import PartySerializer, PartyPaymentSerializer


class _RequireParties:
    """Gated by the Super Admin 'Parties' feature switch."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("parties")]


class _RequirePayments:
    """Gated by the Super Admin 'Payments' feature switch."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("payments")]


class PartyListCreateView(_RequireParties, generics.ListCreateAPIView):
    serializer_class = PartySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["party_type", "is_active"]
    search_fields = ["name", "phone", "email"]
    ordering_fields = ["name", "created_at"]

    def get_queryset(self):
        bid = get_bid(self.request)
        return Party.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        )

    def perform_create(self, serializer):
        business = get_business(self.request)
        if business is None:
            raise ValidationError("No business selected or access denied.")
        serializer.save(business=business)


class PartyDetailView(_RequireParties, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PartySerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return Party.objects.filter(
            business_id=bid,
            business__staff__user=self.request.user,
            business__staff__is_active=True,
            is_deleted=False,
        )

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.balance != 0:
            direction = "owed to you" if instance.balance > 0 else "you owe them"
            return Response(
                {"error": f"Cannot delete '{instance.name}' — outstanding balance of {abs(instance.balance)} ({direction}) must be settled first."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().destroy(request, *args, **kwargs)

    def perform_destroy(self, instance):
        from django.utils import timezone
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])


class PartyPaymentListCreateView(_RequirePayments, generics.ListCreateAPIView):
    serializer_class = PartyPaymentSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["payment_type", "payment_method"]
    ordering_fields = ["date", "created_at"]

    def get_queryset(self):
        bid = get_bid(self.request)
        qs = PartyPayment.objects.filter(
            party__business_id=bid,
            party__business__staff__user=self.request.user,
            party__business__staff__is_active=True,
        ).select_related("party")
        party_id = self.request.query_params.get("party")
        if party_id:
            qs = qs.filter(party_id=party_id)
        return qs

    def perform_create(self, serializer):
        business = get_business(self.request)
        if business is None:
            raise ValidationError("No business selected or access denied.")
        party = serializer.validated_data.get("party")
        if party is None or party.business_id != business.id:
            raise ValidationError({"party": "Invalid party for this business."})
        payment = serializer.save(created_by=self.request.user)
        self._reconcile_payment(payment)
        PartyPaymentSerializer._sync_bank(payment)

    @staticmethod
    def _reconcile_payment(payment):
        """Apply payment to oldest outstanding invoices for the party."""
        from sales.models import Sale
        from purchases.models import Purchase

        remaining = Decimal(str(payment.amount))
        party = payment.party

        if payment.payment_type == "IN":
            # Customer paid us → reduce outstanding sales (oldest first)
            for sale in Sale.objects.filter(
                customer=party, status="CONFIRMED",
                due_amount__gt=0, is_deleted=False,
            ).order_by("sale_date"):
                if remaining <= 0:
                    break
                apply = min(remaining, sale.due_amount)
                sale.paid_amount += apply
                sale.reconciled_amount += apply
                sale.save()                 # triggers due_amount = total - paid_amount
                remaining -= apply

        elif payment.payment_type == "OUT":
            # We paid supplier → reduce outstanding purchases (oldest first)
            for purchase in Purchase.objects.filter(
                supplier=party, status="CONFIRMED",
                due_amount__gt=0, is_deleted=False,
            ).order_by("purchase_date"):
                if remaining <= 0:
                    break
                apply = min(remaining, purchase.due_amount)
                purchase.paid_amount += apply
                purchase.reconciled_amount += apply
                purchase.save()
                remaining -= apply


class PartyPaymentDetailView(_RequirePayments, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PartyPaymentSerializer

    def get_queryset(self):
        bid = get_bid(self.request)
        return PartyPayment.objects.filter(
            party__business_id=bid,
            party__business__staff__user=self.request.user,
            party__business__staff__is_active=True,
        )

    def perform_update(self, serializer):
        business = get_business(self.request)
        if business is None:
            raise ValidationError("No business selected or access denied.")
        party = serializer.validated_data.get("party")
        if party is not None and party.business_id != business.id:
            raise ValidationError({"party": "Invalid party for this business."})
        payment = serializer.save()
        PartyPaymentSerializer._sync_bank(payment)

    def perform_destroy(self, instance):
        from banking.models import BankTransaction
        BankTransaction.objects.filter(reference=f"PARTYPAYMENT-{instance.id}").delete()
        instance.delete()


class PartyLedgerView(_RequireParties, APIView):
    """Combined ledger for a party: sales, purchases, direct payments, and returns."""

    def get(self, request, pk):
        bid = get_bid(request)
        try:
            party = Party.objects.get(
                pk=pk,
                business_id=bid,
                business__staff__user=request.user,
                business__staff__is_active=True,
                is_deleted=False,
            )
        except Party.DoesNotExist:
            return Response({"error": "Party not found."}, status=status.HTTP_404_NOT_FOUND)

        from sales.models import Sale, SaleReturn
        from purchases.models import Purchase, PurchaseReturn

        entries = []

        # ── Sales ────────────────────────────────────────────────────────────
        for s in Sale.objects.filter(customer=party, is_deleted=False).order_by("sale_date"):
            entries.append({
                "date": str(s.sale_date), "type": "SALE",
                "ref": s.invoice_number,
                "debit": float(s.total), "credit": 0.0, "balance": 0.0,
                "note": s.notes or "",
            })
            # Only the portion paid at/after sale creation that did NOT come through a
            # reconciled PartyPayment — the reconciled portion is already represented
            # by that PartyPayment's own PAYMENT_IN entry below, so including all of
            # paid_amount here would double-count it.
            direct_receipt = s.paid_amount - s.reconciled_amount
            if direct_receipt > 0:
                entries.append({
                    "date": str(s.sale_date), "type": "RECEIPT",
                    "ref": s.invoice_number,
                    "debit": 0.0, "credit": float(direct_receipt), "balance": 0.0,
                    "note": f"Payment via {s.payment_method}",
                })

        # ── Sale returns ─────────────────────────────────────────────────────
        for sr in SaleReturn.objects.filter(
            original_sale__customer=party, original_sale__is_deleted=False
        ).order_by("return_date"):
            entries.append({
                "date": str(sr.return_date), "type": "SALE_RETURN",
                "ref": sr.original_sale.invoice_number,
                "debit": 0.0, "credit": float(sr.amount), "balance": 0.0,
                "note": sr.reason or "Sale return",
            })

        # ── Purchases ────────────────────────────────────────────────────────
        for p in Purchase.objects.filter(supplier=party, is_deleted=False).order_by("purchase_date"):
            entries.append({
                "date": str(p.purchase_date), "type": "PURCHASE",
                "ref": p.bill_number,
                "debit": 0.0, "credit": float(p.total), "balance": 0.0,
                "note": p.notes or "",
            })
            # See the matching comment on the sales loop above — exclude the portion
            # already reconciled from a PartyPayment to avoid double-counting it.
            direct_payment = p.paid_amount - p.reconciled_amount
            if direct_payment > 0:
                entries.append({
                    "date": str(p.purchase_date), "type": "PAYMENT_OUT",
                    "ref": p.bill_number,
                    "debit": float(direct_payment), "credit": 0.0, "balance": 0.0,
                    "note": f"Payment via {p.payment_method}",
                })

        # ── Purchase returns ─────────────────────────────────────────────────
        for pr in PurchaseReturn.objects.filter(
            original_purchase__supplier=party, original_purchase__is_deleted=False
        ).order_by("return_date"):
            entries.append({
                "date": str(pr.return_date), "type": "PURCHASE_RETURN",
                "ref": pr.original_purchase.bill_number,
                "debit": float(pr.amount), "credit": 0.0, "balance": 0.0,
                "note": pr.reason or "Purchase return",
            })

        # ── Direct payments ──────────────────────────────────────────────────
        for pay in PartyPayment.objects.filter(party=party).order_by("date"):
            is_in = pay.payment_type == "IN"
            entries.append({
                "date": str(pay.date),
                "type": "PAYMENT_IN" if is_in else "PAYMENT_OUT",
                "ref": f"PMT-{pay.id}",
                "debit": float(pay.amount) if not is_in else 0.0,
                "credit": float(pay.amount) if is_in else 0.0,
                "balance": 0.0,
                "note": pay.note or "",
            })

        # ── Running balance ──────────────────────────────────────────────────
        entries.sort(key=lambda x: x["date"])
        balance = float(party.opening_balance)
        for e in entries:
            balance += e["debit"] - e["credit"]
            e["balance"] = round(balance, 2)

        total_debit  = sum(e["debit"]  for e in entries)
        total_credit = sum(e["credit"] for e in entries)

        return Response({
            "party": PartySerializer(party).data,
            "opening_balance": float(party.opening_balance),
            "entries": entries,
            "total_debit":      round(total_debit, 2),
            "total_credit":     round(total_credit, 2),
            "closing_balance":  round(float(party.opening_balance) + total_debit - total_credit, 2),
        })


class PartyBulkImportView(APIView):
    """Bulk create parties from Excel import. Accepts list of party objects. Premium only."""

    permission_classes = [IsPremiumBusiness, HasActiveSubscription, require_feature("excel_import")]

    def post(self, request):
        bid = get_bid(request)
        if not bid:
            return Response({"error": "No business selected."}, status=status.HTTP_400_BAD_REQUEST)
        rows = request.data.get("parties", [])
        if not isinstance(rows, list):
            return Response({"error": "Expected 'parties' list."}, status=status.HTTP_400_BAD_REQUEST)

        valid_types = [t for t, _ in Party.TYPE_CHOICES]
        created, skipped = [], []
        for row in rows:
            name = (row.get("name") or "").strip()
            if not name:
                skipped.append({"row": row, "reason": "Missing name"})
                continue
            party_type = (row.get("party_type") or "CUSTOMER").strip().upper()
            if party_type not in valid_types:
                party_type = "CUSTOMER"
            try:
                party = Party.objects.create(
                    business_id=bid,
                    name=name,
                    party_type=party_type,
                    phone=row.get("phone") or "",
                    email=row.get("email") or "",
                    address=row.get("address") or "",
                    opening_balance=row.get("opening_balance") or 0,
                )
                created.append(party.id)
            except Exception as e:
                skipped.append({"row": row, "reason": str(e)})

        return Response({"created": len(created), "skipped": len(skipped), "skipped_details": skipped})
