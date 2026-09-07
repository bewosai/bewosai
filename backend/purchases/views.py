import re

from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import generics, status, parsers, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.views import APIView
from rest_framework.response import Response

from bewosai.pagination import LargePageNumberPagination
from bewosai.permissions import BusinessNotArchivedForWrites, HasActiveSubscription, require_feature, require_staff_permission
from bewosai.utils import get_business
from .models import Purchase, PurchaseReturn
from .serializers import PurchaseSerializer, PurchaseReturnSerializer


class _RequirePurchases:
    """Gated by the Super Admin 'Purchases' feature switch, and by whether
    the current staff member has been granted the 'purchases' module."""
    permission_classes = [permissions.IsAuthenticated, BusinessNotArchivedForWrites, HasActiveSubscription, require_feature("purchases"), require_staff_permission("purchases")]


def _next_bill_number(business):
    last = Purchase.objects.filter(business=business).order_by("-id").first()
    if last:
        m = re.search(r"(\d+)$", last.bill_number)
        num = int(m.group(1)) + 1 if m else 1
    else:
        num = 1
    return f"PUR-{num:04d}"


class PurchaseNextNumberView(_RequirePurchases, APIView):
    def get(self, request):
        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response({"next_number": _next_bill_number(biz)})


class PurchaseListCreateView(_RequirePurchases, generics.ListCreateAPIView):
    serializer_class = PurchaseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]
    # See the matching comment on sales.SaleListCreateView — Reports and the
    # Purchases list both need every matching purchase, not just the newest 50.
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        biz = get_business(self.request)
        if not biz:
            return Purchase.objects.none()
        qs = Purchase.objects.filter(business=biz, is_deleted=False).select_related(
            "supplier", "created_by"
        )
        supplier = self.request.query_params.get("supplier")
        if supplier:
            qs = qs.filter(supplier_id=supplier)
        status_param = self.request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param)
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        if date_from:
            qs = qs.filter(purchase_date__gte=date_from)
        if date_to:
            qs = qs.filter(purchase_date__lte=date_to)
        return qs

    def perform_create(self, serializer):
        biz = get_business(self.request)
        bill_number = self.request.data.get("bill_number") or _next_bill_number(biz)
        # Same collision risk as Sale.invoice_number (see sales/views.py) —
        # client-supplied, DB-unique per business, now reachable via the
        # offline outbox too. Renumber on collision instead of 500ing.
        for _ in range(5):
            try:
                with transaction.atomic():
                    serializer.save(business=biz, bill_number=bill_number, created_by=self.request.user)
                return
            except IntegrityError:
                bill_number = _next_bill_number(biz)
        raise ValidationError("Could not assign a unique bill number — please try again.")


class PurchaseDetailView(_RequirePurchases, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PurchaseSerializer
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        biz = get_business(self.request)
        return Purchase.objects.filter(business=biz, is_deleted=False)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted", "deleted_at"])


class PurchaseReturnListCreateView(_RequirePurchases, generics.ListCreateAPIView):
    serializer_class = PurchaseReturnSerializer

    def get_queryset(self):
        biz = get_business(self.request)
        if not biz:
            return PurchaseReturn.objects.none()
        return PurchaseReturn.objects.filter(business=biz)

    def perform_create(self, serializer):
        biz = get_business(self.request)
        serializer.save(business=biz, created_by=self.request.user)


class RecycleBinView(APIView):
    """Lists all soft-deleted records across models for the current business."""

    def get(self, request):
        from sales.models import Sale, Quotation
        from parties.models import Party, PartyPayment
        from expenses.models import Expense
        from inventory.models import Product
        from banking.models import BankAccount, BankTransaction

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        result = []
        for sale in Sale.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "sale",
                "id": sale.id,
                "label": f"Invoice {sale.invoice_number}",
                "deleted_at": sale.deleted_at,
            })
        for purchase in Purchase.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "purchase",
                "id": purchase.id,
                "label": f"Purchase {purchase.bill_number}",
                "deleted_at": purchase.deleted_at,
            })
        for party in Party.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "party",
                "id": party.id,
                "label": f"Party: {party.name}",
                "deleted_at": party.deleted_at,
            })
        for expense in Expense.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "expense",
                "id": expense.id,
                "label": f"Expense Rs.{expense.amount} ({expense.date})",
                "deleted_at": expense.deleted_at,
            })
        for product in Product.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "product",
                "id": product.id,
                "label": f"Product: {product.name}",
                "deleted_at": product.deleted_at,
            })
        for payment in PartyPayment.objects.filter(party__business=biz, is_deleted=True).select_related("party"):
            direction = "Received from" if payment.payment_type == "IN" else "Paid to"
            result.append({
                "type": "payment",
                "id": payment.id,
                "label": f"{direction} {payment.party.name}: Rs.{payment.amount}",
                "deleted_at": payment.deleted_at,
            })
        for quotation in Quotation.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "quotation",
                "id": quotation.id,
                "label": f"Quotation {quotation.quotation_number}",
                "deleted_at": quotation.deleted_at,
            })
        for account in BankAccount.objects.filter(business=biz, is_deleted=True):
            result.append({
                "type": "bank_account",
                "id": account.id,
                "label": f"Account: {account.account_name}",
                "deleted_at": account.deleted_at,
            })
        for txn in BankTransaction.objects.filter(account__business=biz, is_deleted=True).select_related("account"):
            result.append({
                "type": "bank_transaction",
                "id": txn.id,
                "label": f"{txn.transaction_type.title()} Rs.{txn.amount} ({txn.account.account_name})",
                "deleted_at": txn.deleted_at,
            })

        result.sort(key=lambda x: x["deleted_at"] or timezone.now(), reverse=True)
        return Response(result)


class RecycleBinRestoreView(APIView):
    def post(self, request, record_type, pk):
        from sales.models import Sale, Quotation
        from parties.models import Party, PartyPayment
        from parties.serializers import PartyPaymentSerializer
        from expenses.models import Expense
        from inventory.models import Product
        from banking.models import BankAccount, BankTransaction

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            if record_type == "sale":
                obj = Sale.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "purchase":
                obj = Purchase.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "party":
                obj = Party.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "expense":
                obj = Expense.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "product":
                obj = Product.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "payment":
                obj = PartyPayment.objects.get(id=pk, party__business=biz, is_deleted=True)
            elif record_type == "quotation":
                obj = Quotation.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "bank_account":
                obj = BankAccount.objects.get(id=pk, business=biz, is_deleted=True)
            elif record_type == "bank_transaction":
                obj = BankTransaction.objects.get(id=pk, account__business=biz, is_deleted=True)
            else:
                return Response({"error": "Unknown record type."}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({"error": "Record not found."}, status=status.HTTP_404_NOT_FOUND)

        obj.is_deleted = False
        obj.deleted_at = None
        obj.save(update_fields=["is_deleted", "deleted_at"])

        if record_type == "payment":
            # Mirror image of _unreconcile_payment (parties.views) — re-apply
            # the same allocation amounts to whatever sale/purchase they were
            # against, and recreate the mirrored BankTransaction, so the
            # party's balance and bank balance go back to exactly what they
            # were before this payment was deleted.
            for allocation in obj.allocations.select_related("sale", "purchase"):
                if allocation.sale is not None:
                    sale = allocation.sale
                    sale.paid_amount += allocation.amount
                    sale.reconciled_amount += allocation.amount
                    sale.save()
                elif allocation.purchase is not None:
                    purchase = allocation.purchase
                    purchase.paid_amount += allocation.amount
                    purchase.reconciled_amount += allocation.amount
                    purchase.save()
            PartyPaymentSerializer._sync_bank(obj)

        return Response({"message": "Restored successfully."})


class RecycleBinPermanentDeleteView(APIView):
    def delete(self, request, record_type, pk):
        from sales.models import Sale, Quotation
        from parties.models import Party, PartyPayment
        from expenses.models import Expense
        from inventory.models import Product
        from banking.models import BankAccount, BankTransaction

        biz = get_business(request)
        if not biz:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            if record_type == "sale":
                Sale.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "purchase":
                Purchase.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "party":
                Party.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "expense":
                Expense.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "product":
                Product.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "payment":
                # Cascades to the payment's PaymentAllocation rows; the sale/
                # purchase amounts and mirrored BankTransaction were already
                # reversed when this payment was first soft-deleted.
                PartyPayment.objects.get(id=pk, party__business=biz, is_deleted=True).delete()
            elif record_type == "quotation":
                Quotation.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "bank_account":
                # Cascades to every BankTransaction under this account,
                # deleted or not — permanently deleting the account means
                # permanently deleting its whole transaction history.
                BankAccount.objects.get(id=pk, business=biz, is_deleted=True).delete()
            elif record_type == "bank_transaction":
                BankTransaction.objects.get(id=pk, account__business=biz, is_deleted=True).delete()
            else:
                return Response({"error": "Unknown record type."}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({"error": "Record not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response(status=status.HTTP_204_NO_CONTENT)
