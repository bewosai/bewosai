from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import generics, permissions
from rest_framework.serializers import ModelSerializer
from django.db.models import Count, Sum
from django.utils import timezone
from datetime import timedelta
from accounts.models import User, Business, LoginActivity
from .models import SupportTicket, Announcement


class IsPlatformAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.is_platform_admin


class PlatformStatsView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        now = timezone.now()
        last_30 = now - timedelta(days=30)

        total_users = User.objects.count()
        total_businesses = Business.objects.count()
        active_businesses = Business.objects.filter(status="ACTIVE").count()
        premium_count = Business.objects.filter(plan="PREMIUM").count()
        new_this_month = Business.objects.filter(created_at__gte=last_30).count()
        recent_logins = LoginActivity.objects.filter(timestamp__gte=last_30, success=True).count()

        return Response({
            "total_users": total_users,
            "total_businesses": total_businesses,
            "active_businesses": active_businesses,
            "suspended_businesses": total_businesses - active_businesses,
            "premium_count": premium_count,
            "free_count": active_businesses - premium_count,
            "new_this_month": new_this_month,
            "logins_last_30_days": recent_logins,
        })


class BusinessManagementView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        from accounts.serializers import BusinessSerializer
        plan = request.query_params.get("plan")
        status = request.query_params.get("status")
        qs = Business.objects.all().order_by("-created_at")
        if plan:
            qs = qs.filter(plan=plan)
        if status:
            qs = qs.filter(status=status)
        data = BusinessSerializer(qs, many=True).data
        return Response(data)


class BusinessActionView(APIView):
    permission_classes = [IsPlatformAdmin]

    def patch(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Not found"}, status=404)

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
            return Response({"error": "Unknown action"}, status=400)
        biz.save()
        from accounts.serializers import BusinessSerializer
        return Response(BusinessSerializer(biz).data)


class UserManagementView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        from accounts.serializers import UserSerializer
        users = User.objects.all().order_by("-created_at")
        return Response(UserSerializer(users, many=True).data)


class LoginActivityView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        qs = LoginActivity.objects.order_by("-timestamp")
        user_id = request.query_params.get("user_id")
        if user_id:
            qs = qs.filter(user_id=user_id)
        logs = qs[:500]
        data = [
            {
                "id": l.id,
                "user": l.user.email,
                "user_id": l.user_id,
                "ip": l.ip_address,
                "success": l.success,
                "timestamp": l.timestamp,
            }
            for l in logs
        ]
        return Response(data)


class AnnouncementSerializer(ModelSerializer):
    class Meta:
        model = Announcement
        fields = "__all__"


class AnnouncementListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AnnouncementSerializer
    queryset = Announcement.objects.all()


class TicketSerializer(ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = "__all__"


class TicketListView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = TicketSerializer
    queryset = SupportTicket.objects.all()


class TicketDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = TicketSerializer
    queryset = SupportTicket.objects.all()


class SubmitTicketView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = TicketSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201)
        return Response(serializer.errors, status=400)
