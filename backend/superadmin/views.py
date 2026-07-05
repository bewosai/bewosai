from datetime import timedelta

from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Count, Sum
from django.utils import timezone

from accounts.models import User, Business, LoginActivity
from accounts.serializers import UserSerializer, BusinessSerializer
from .models import SupportTicket, Announcement
from .serializers import SupportTicketSerializer, AnnouncementSerializer


class IsPlatformAdmin(permissions.BasePermission):
    """Grants access only to users with is_platform_admin=True."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_platform_admin
        )


# ── Platform overview ──────────────────────────────────────────────────────────

class PlatformStatsView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        last_30 = timezone.now() - timedelta(days=30)

        total_users = User.objects.count()
        total_businesses = Business.objects.count()
        active_businesses = Business.objects.filter(status=Business.STATUS_ACTIVE).count()
        suspended_businesses = total_businesses - active_businesses
        premium_count = Business.objects.filter(plan=Business.PLAN_PREMIUM).count()
        new_this_month = Business.objects.filter(created_at__gte=last_30).count()
        new_users_this_month = User.objects.filter(created_at__gte=last_30).count()
        logins_last_30 = LoginActivity.objects.filter(
            timestamp__gte=last_30, success=True
        ).count()

        return Response({
            "total_users": total_users,
            "total_businesses": total_businesses,
            "active_businesses": active_businesses,
            "suspended_businesses": suspended_businesses,
            "premium_count": premium_count,
            "free_count": active_businesses - premium_count,
            "new_businesses_this_month": new_this_month,
            "new_users_this_month": new_users_this_month,
            "logins_last_30_days": logins_last_30,
        })


# ── Business management ────────────────────────────────────────────────────────

class BusinessManagementView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        plan = request.query_params.get("plan")
        status_filter = request.query_params.get("status")
        search = request.query_params.get("search", "")

        qs = Business.objects.all().order_by("-created_at")
        if plan:
            qs = qs.filter(plan=plan)
        if status_filter:
            qs = qs.filter(status=status_filter)
        if search:
            qs = qs.filter(name__icontains=search)

        return Response(BusinessSerializer(qs, many=True).data)


class BusinessActionView(APIView):
    permission_classes = [IsPlatformAdmin]

    def patch(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action")
        if action == "suspend":
            biz.status = Business.STATUS_SUSPENDED
        elif action == "activate":
            biz.status = Business.STATUS_ACTIVE
        elif action == "upgrade":
            biz.plan = Business.PLAN_PREMIUM
        elif action == "downgrade":
            biz.plan = Business.PLAN_FREE
        else:
            return Response(
                {"error": f"Unknown action '{action}'. Use: suspend, activate, upgrade, downgrade."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        biz.save()
        return Response(BusinessSerializer(biz).data)


# ── User management ────────────────────────────────────────────────────────────

class UserManagementView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        search = request.query_params.get("search", "")
        qs = User.objects.all().order_by("-created_at")
        if search:
            qs = qs.filter(email__icontains=search) | qs.filter(name__icontains=search)
        return Response(UserSerializer(qs, many=True).data)


class UserActionView(APIView):
    permission_classes = [IsPlatformAdmin]

    def patch(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action")
        if action == "deactivate":
            user.is_active = False
        elif action == "activate":
            user.is_active = True
        elif action == "make_admin":
            user.is_platform_admin = True
        elif action == "remove_admin":
            if user.pk == request.user.pk:
                return Response({"error": "Cannot remove your own admin status."}, status=400)
            user.is_platform_admin = False
        else:
            return Response({"error": "Unknown action."}, status=status.HTTP_400_BAD_REQUEST)

        user.save()
        return Response(UserSerializer(user).data)


# ── Login activity ─────────────────────────────────────────────────────────────

class LoginActivityView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        qs = LoginActivity.objects.select_related("user").order_by("-timestamp")
        user_id = request.query_params.get("user_id")
        if user_id:
            qs = qs.filter(user_id=user_id)

        data = [
            {
                "id": la.id,
                "user": la.user.email,
                "user_id": la.user_id,
                "ip": la.ip_address,
                "success": la.success,
                "timestamp": la.timestamp,
                "logout_time": la.logout_time,
                "session_duration": str(la.session_duration) if la.session_duration else None,
            }
            for la in qs[:500]
        ]
        return Response(data)


# ── Announcements ──────────────────────────────────────────────────────────────

class AnnouncementListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AnnouncementSerializer
    queryset = Announcement.objects.all()


class AnnouncementDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AnnouncementSerializer
    queryset = Announcement.objects.all()


# Public endpoint — any authenticated user can read active announcements
class ActiveAnnouncementsView(APIView):
    def get(self, request):
        qs = Announcement.objects.filter(is_active=True).order_by("-created_at")[:10]
        return Response(AnnouncementSerializer(qs, many=True).data)


# ── Support tickets ────────────────────────────────────────────────────────────

class TicketListView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = SupportTicketSerializer

    def get_queryset(self):
        qs = SupportTicket.objects.all()
        ticket_status = self.request.query_params.get("status")
        if ticket_status:
            qs = qs.filter(status=ticket_status)
        return qs


class TicketDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = SupportTicketSerializer
    queryset = SupportTicket.objects.all()


class SubmitTicketView(APIView):
    """Any authenticated user can submit a support ticket."""

    def post(self, request):
        serializer = SupportTicketSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user_email=request.user.email)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ── User CRUD ──────────────────────────────────────────────────────────────────

class UserCreateAdminView(APIView):
    """Platform admin: create a new user account directly."""
    permission_classes = [IsPlatformAdmin]

    def post(self, request):
        from accounts.models import ACCOUNT_BUSINESS
        email = request.data.get("email", "").strip().lower()
        name = request.data.get("name", "").strip()
        is_admin = bool(request.data.get("is_platform_admin", False))

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email=email).exists():
            return Response({"error": "A user with this email already exists."}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.create_user(
            email=email,
            name=name or email.split("@")[0].capitalize(),
            account_type=ACCOUNT_BUSINESS,
            is_platform_admin=is_admin,
            is_verified=True,
        )
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class UserDeleteAdminView(APIView):
    """Platform admin: permanently delete a user and all their data."""
    permission_classes = [IsPlatformAdmin]

    def delete(self, request, pk):
        if pk == request.user.pk:
            return Response({"error": "Cannot delete your own account."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ── Business full edit / delete ────────────────────────────────────────────────

class BusinessEditDeleteView(APIView):
    """Platform admin: edit or permanently delete a business."""
    permission_classes = [IsPlatformAdmin]

    def patch(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = BusinessSerializer(biz, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        biz.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BusinessDataView(APIView):
    """Platform admin: cross-business data summary for a specific business."""
    permission_classes = [IsPlatformAdmin]

    def get(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        from sales.models import Sale
        from purchases.models import Purchase
        from expenses.models import Expense
        from inventory.models import Product
        from parties.models import Party

        sales_agg = Sale.objects.filter(business=biz).aggregate(
            count=Count("id"), total=Sum("total")
        )
        purchases_agg = Purchase.objects.filter(business=biz).aggregate(
            count=Count("id"), total=Sum("total")
        )
        expenses_agg = Expense.objects.filter(business=biz).aggregate(
            count=Count("id"), total=Sum("amount")
        )

        return Response({
            "business": BusinessSerializer(biz).data,
            "sales": {
                "count": sales_agg["count"] or 0,
                "total": float(sales_agg["total"] or 0),
            },
            "purchases": {
                "count": purchases_agg["count"] or 0,
                "total": float(purchases_agg["total"] or 0),
            },
            "expenses": {
                "count": expenses_agg["count"] or 0,
                "total": float(expenses_agg["total"] or 0),
            },
            "inventory_count": Product.objects.filter(business=biz, is_deleted=False).count(),
            "parties_count": Party.objects.filter(business=biz, is_deleted=False).count(),
        })
