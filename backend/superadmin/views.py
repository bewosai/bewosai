from datetime import timedelta

from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.db import models
from django.db.models import Count, Sum
from django.utils import timezone

from accounts.models import User, Business, LoginActivity
from accounts.serializers import UserSerializer, BusinessSerializer
from bewosai.pagination import LargePageNumberPagination
from bewosai.utils import get_business
from .models import (
    SupportTicket, Announcement, Feature,
    License, BusinessFeatureOverride, LicenseAuditLog, ActivityLog,
)
from .serializers import (
    SupportTicketSerializer, AnnouncementSerializer, FeatureSerializer,
    LicenseSerializer, LicenseAuditLogSerializer, ActivityLogSerializer,
)


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
        suspended_businesses = Business.objects.filter(status=Business.STATUS_SUSPENDED).count()
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
        owner = request.query_params.get("owner")

        qs = Business.objects.select_related("owner").order_by("-created_at")
        if plan:
            qs = qs.filter(plan=plan)
        if status_filter:
            qs = qs.filter(status=status_filter)
        if owner:
            # Lets Super Admin's Users tab show/manage a user's plan(s)
            # without switching to the Businesses tab and searching there.
            qs = qs.filter(owner_id=owner)
        if search:
            # Business's own name/phone/email, or its owner's — so Super
            # Admin can find a business from whichever detail they have on
            # hand (the owner's phone number is usually what support gets
            # first, not the business name).
            qs = (
                qs.filter(name__icontains=search)
                | qs.filter(phone__icontains=search)
                | qs.filter(email__icontains=search)
                | qs.filter(owner__phone__icontains=search)
                | qs.filter(owner__email__icontains=search)
                | qs.filter(owner__name__icontains=search)
            )

        paginator = LargePageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(BusinessSerializer(page, many=True).data)


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
        elif action == "set_staff_limit":
            # Overrides the plan-based staff cap (Free=1/Premium=8) for this
            # business only — the one piece of a tenant's setup a platform
            # admin can change; everything else about their business (name,
            # contact info, financial records) is admin-view-only.
            limit = request.data.get("limit")
            if limit in (None, ""):
                biz.staff_limit_override = None
            else:
                try:
                    limit = int(limit)
                except (TypeError, ValueError):
                    return Response({"error": "limit must be a whole number, or blank to clear the override."}, status=status.HTTP_400_BAD_REQUEST)
                if limit < 0:
                    return Response({"error": "limit cannot be negative."}, status=status.HTTP_400_BAD_REQUEST)
                biz.staff_limit_override = limit
        elif action == "set_trial":
            # Grants or revokes an admin-controlled trial window for one
            # platform (web or mobile) — independent of the automatic
            # 120-day trial and of the license system. See
            # Business.has_active_platform_trial / has_access.
            platform = request.data.get("platform")
            if platform not in ("web", "mobile"):
                return Response({"error": "platform must be 'web' or 'mobile'."}, status=status.HTTP_400_BAD_REQUEST)
            prefix = f"{platform}_trial_"
            if request.data.get("enabled"):
                start = request.data.get("start_date")
                end = request.data.get("end_date")
                if not start or not end:
                    return Response(
                        {"error": "start_date and end_date are required to enable a trial."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                if end < start:
                    return Response({"error": "end_date cannot be before start_date."}, status=status.HTTP_400_BAD_REQUEST)
                setattr(biz, prefix + "enabled", True)
                setattr(biz, prefix + "start", start)
                setattr(biz, prefix + "end", end)
            else:
                setattr(biz, prefix + "enabled", False)
                setattr(biz, prefix + "start", None)
                setattr(biz, prefix + "end", None)
        else:
            return Response(
                {"error": f"Unknown action '{action}'. Use: suspend, activate, upgrade, downgrade, set_staff_limit, set_trial."},
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
            qs = (
                qs.filter(email__icontains=search)
                | qs.filter(name__icontains=search)
                | qs.filter(phone__icontains=search)
            )

        paginator = LargePageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(UserSerializer(page, many=True).data)


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
        elif action == "remove_admin":
            # Demotion only — granting admin status is no longer possible
            # from this endpoint at all (removed feature). An existing
            # admin can still be safely demoted if needed.
            if user.pk == request.user.pk:
                return Response({"error": "Cannot remove your own admin status."}, status=400)
            user.is_platform_admin = False
        elif action == "set_business_limit":
            # Overrides the plan-based business-count cap (Free=2/Premium=5)
            # for this user only — see BusinessListCreateView.create.
            limit = request.data.get("limit")
            if limit in (None, ""):
                user.business_limit_override = None
            else:
                try:
                    limit = int(limit)
                except (TypeError, ValueError):
                    return Response({"error": "limit must be a whole number, or blank to clear the override."}, status=status.HTTP_400_BAD_REQUEST)
                if limit < 0:
                    return Response({"error": "limit cannot be negative."}, status=status.HTTP_400_BAD_REQUEST)
                user.business_limit_override = limit
        else:
            return Response({"error": "Unknown action."}, status=status.HTTP_400_BAD_REQUEST)

        user.save()
        return Response(UserSerializer(user).data)


class UserSummaryView(APIView):
    """
    Super Admin: real usage totals for this user across every business they
    own — actual row counts from Sales/Purchases/Expenses/Products/Parties,
    not derived from ActivityLog (which only exists from whenever that
    feature shipped, so it would under-count anything older). Also surfaces
    their business-count limit override, since "how many businesses can they
    still create" is exactly what that field controls.
    """
    permission_classes = [IsPlatformAdmin]

    def get(self, request, pk):
        from sales.models import Sale
        from purchases.models import Purchase
        from expenses.models import Expense
        from inventory.models import Product
        from parties.models import Party

        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        owned = models.Q(business__owner_id=pk)
        return Response({
            "business_count": user.businesses.count(),
            "business_limit_override": user.business_limit_override,
            "total_sales": Sale.objects.filter(owned, is_deleted=False).count(),
            "total_purchases": Purchase.objects.filter(owned, is_deleted=False).count(),
            "total_expenses": Expense.objects.filter(owned, is_deleted=False).count(),
            "total_products": Product.objects.filter(owned, is_deleted=False).count(),
            "total_parties": Party.objects.filter(owned, is_deleted=False).count(),
        })


class UserActivityView(generics.ListAPIView):
    """
    Super Admin: what has this user actually done — every Sale, Purchase,
    Expense, Quotation, Product, Party, Payment, and Bank Account/Transaction
    created or permanently deleted, across every business they own. Populated
    by superadmin.signals, not per-view logging — see ActivityLog's docstring.
    """
    permission_classes = [IsPlatformAdmin]
    serializer_class = ActivityLogSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        return ActivityLog.objects.filter(business__owner_id=self.kwargs["pk"]).select_related("business", "user")


# ── Login activity ─────────────────────────────────────────────────────────────

def _device_label(user_agent):
    """Reduces a raw User-Agent string to a short 'OS · Browser' label for
    the login activity list — best-effort substring matching, not a real UA
    parser, since Super Admin just needs "was this a phone or a desktop
    browser", not exact version numbers."""
    if not user_agent:
        return "Unknown device"
    ua = user_agent.lower()
    if "okhttp" in ua or "dart" in ua or ua.strip() == "":
        os_label = "Mobile App"
    elif "android" in ua:
        os_label = "Android"
    elif "iphone" in ua or "ipad" in ua or "ios" in ua:
        os_label = "iOS"
    elif "windows" in ua:
        os_label = "Windows"
    elif "mac os" in ua or "macintosh" in ua:
        os_label = "Mac"
    elif "linux" in ua:
        os_label = "Linux"
    else:
        os_label = "Unknown OS"

    if "edg/" in ua:
        browser = "Edge"
    elif "chrome/" in ua:
        browser = "Chrome"
    elif "firefox/" in ua:
        browser = "Firefox"
    elif "safari/" in ua and "chrome/" not in ua:
        browser = "Safari"
    else:
        browser = None

    return f"{os_label} · {browser}" if browser else os_label


class LoginActivityView(APIView):
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        qs = LoginActivity.objects.select_related("user").order_by("-timestamp")
        user_id = request.query_params.get("user_id")
        if user_id:
            qs = qs.filter(user_id=user_id)
        search = request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                models.Q(user__name__icontains=search)
                | models.Q(user__email__icontains=search)
                | models.Q(user__phone__icontains=search)
            )

        paginator = LargePageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        data = [
            {
                "id": la.id,
                "user": la.user.email,
                "user_name": la.user.name,
                "user_id": la.user_id,
                "ip": la.ip_address,
                "user_agent": la.user_agent,
                "device": _device_label(la.user_agent),
                "success": la.success,
                "timestamp": la.timestamp,
                "logout_time": la.logout_time,
                "session_duration": str(la.session_duration) if la.session_duration else None,
            }
            for la in page
        ]
        return paginator.get_paginated_response(data)


# ── Announcements ──────────────────────────────────────────────────────────────

class AnnouncementListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AnnouncementSerializer
    pagination_class = LargePageNumberPagination
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
    pagination_class = LargePageNumberPagination

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
    """Any authenticated user can submit a support ticket/comment."""

    def post(self, request):
        serializer = SupportTicketSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user_email=request.user.email)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyTicketsView(generics.ListAPIView):
    """The comment box's "your comments" list — every ticket *this* user has
    submitted (own email only, not IsPlatformAdmin-gated like TicketListView),
    so they can see whether Super Admin has replied without needing admin
    access themselves."""
    serializer_class = SupportTicketSerializer

    def get_queryset(self):
        return SupportTicket.objects.filter(user_email=self.request.user.email)


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


# ── Business delete ──────────────────────────────────────────────────────────

class BusinessEditDeleteView(APIView):
    """Platform admin: permanently delete a business (e.g. abuse/spam
    cleanup). Deliberately no edit capability here — a platform admin can
    view a tenant's data, change its plan, and set a staff-count override
    (BusinessActionView), but must never modify the business's own profile
    or records; that stays owner-only."""
    permission_classes = [IsPlatformAdmin]

    def delete(self, request, pk):
        try:
            biz = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)
        biz.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ── Feature management (admin only) ─────────────────────────────────────────────

class FeatureManagementListView(generics.ListAPIView):
    """Super Admin: list every feature with its current toggle state, for the
    Feature Management table (Feature | Status | Available To | Action)."""
    permission_classes = [IsPlatformAdmin]
    serializer_class = FeatureSerializer
    queryset = Feature.objects.all()


class FeatureToggleView(APIView):
    """Super Admin: patch any of a feature's toggle fields by its key."""
    permission_classes = [IsPlatformAdmin]

    def patch(self, request, key):
        try:
            feature = Feature.objects.get(key=key)
        except Feature.DoesNotExist:
            return Response({"error": "Feature not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = FeatureSerializer(feature, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EffectiveFeaturesView(APIView):
    """
    Any authenticated user: the effective on/off map for their current
    business on the calling platform (?platform=mobile|desktop, or the
    X-Platform header — see bewosai.permissions.get_platform). This is the
    single source both React and Flutter read, so they can never show a
    different feature set for the same business.
    """

    def get(self, request):
        from accounts.models import StaffMember
        from bewosai.permissions import get_platform

        business = get_business(request)
        platform = get_platform(request)
        overrides = {}
        if business:
            overrides = {
                o.feature_key: o.enabled
                for o in BusinessFeatureOverride.objects.filter(business=business)
            }

        # Modules an individual (non-owner) staff member has been explicitly
        # denied view access to — folded into the same effective map the
        # frontend already reads via FeatureGate/isFeatureEnabled, so a
        # staff-level denial hides that nav item and blocks the page exactly
        # like a platform-level toggle would, with no separate gating logic
        # needed anywhere. Staff permissions are keyed by the Staff UI's own
        # module names (client/src/pages/StaffPage.jsx's MODULES), which
        # don't all match these Super Admin feature keys one-to-one.
        FEATURE_TO_STAFF_MODULE = {"pos": "sales", "staff_management": "staff"}
        staff_view_denied = set()
        if business and business.owner_id != request.user.id:
            staff = business.staff.filter(user=request.user, is_active=True).first()
            if staff and staff.role != StaffMember.ROLE_OWNER:
                for feature in Feature.objects.all():
                    module_key = FEATURE_TO_STAFF_MODULE.get(feature.key, feature.key)
                    module_perms = staff.permissions.get(module_key)
                    if isinstance(module_perms, dict) and module_perms.get("view") is False:
                        staff_view_denied.add(feature.key)

        features = {
            f.key: (overrides[f.key] if f.key in overrides else f.is_available_on(platform, business))
            and f.key not in staff_view_denied
            for f in Feature.objects.all()
        }
        return Response({"platform": platform, "features": features})


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

        sales_agg = Sale.objects.filter(business=biz, is_deleted=False).aggregate(
            count=Count("id"), total=Sum("total")
        )
        purchases_agg = Purchase.objects.filter(business=biz, is_deleted=False).aggregate(
            count=Count("id"), total=Sum("total")
        )
        expenses_agg = Expense.objects.filter(business=biz, is_deleted=False).aggregate(
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


# ── Licensing ────────────────────────────────────────────────────────────────

def _log(*, actor, action, business, license=None, old_value="", new_value=""):
    LicenseAuditLog.objects.create(
        actor=actor, action=action, business=business, license=license,
        old_value=str(old_value), new_value=str(new_value),
    )


class LicenseListView(generics.ListAPIView):
    """
    Super Admin: filterable license table (Code | Business | Plan | Duration
    | Start | Expiry | Status | Actions). Filters: duration, status, business
    search (name/owner email), and start/expiry date ranges — see section 12
    of the license spec for the exact filter set.
    """
    permission_classes = [IsPlatformAdmin]
    serializer_class = LicenseSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        qs = License.objects.select_related("business", "business__owner", "created_by").all()
        params = self.request.query_params

        duration = params.get("duration_type")
        if duration:
            qs = qs.filter(duration_type=duration)

        status_filter = params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)

        search = params.get("search", "").strip()
        if search:
            qs = qs.filter(
                models.Q(business__name__icontains=search)
                | models.Q(email_snapshot__icontains=search)
                | models.Q(business__owner__email__icontains=search)
                | models.Q(business__owner__name__icontains=search)
            )

        for param, field in [
            ("start_from", "start_date__gte"), ("start_to", "start_date__lte"),
            ("expiry_from", "expiry_date__gte"), ("expiry_to", "expiry_date__lte"),
        ]:
            value = params.get(param)
            if value:
                qs = qs.filter(**{field: value})

        year = params.get("year")
        if year:
            qs = qs.filter(models.Q(start_date__year=year) | models.Q(expiry_date__year=year))

        return qs


class LicenseYearsView(APIView):
    """Distinct years present across license start/expiry dates, for the
    year filter dropdown — generated from real data instead of a hardcoded
    5-year list, per section 12."""
    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        years = set()
        for row in License.objects.values_list("start_date", "expiry_date"):
            for d in row:
                if d:
                    years.add(d.year)
        return Response(sorted(years, reverse=True))


class LicenseGenerateView(APIView):
    permission_classes = [IsPlatformAdmin]

    def post(self, request):
        business_id = request.data.get("business")
        duration_type = request.data.get("duration_type")
        if not business_id or not duration_type:
            return Response(
                {"error": "'business' and 'duration_type' are required."}, status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            business = Business.objects.get(pk=business_id)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        if duration_type not in dict(License.DURATION_CHOICES):
            return Response({"error": "Invalid duration_type."}, status=status.HTTP_400_BAD_REQUEST)

        duration_days = request.data.get("duration_days")
        if duration_type == License.DURATION_CUSTOM:
            try:
                duration_days = int(duration_days)
                assert duration_days > 0
            except (TypeError, ValueError, AssertionError):
                return Response(
                    {"error": "'duration_days' must be a positive integer for a custom duration."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        start_date = request.data.get("start_date") or None

        try:
            license_obj = License.generate(
                business=business, duration_type=duration_type,
                start_date=start_date, duration_days=duration_days,
                created_by=request.user,
            )
        except (ValueError, RuntimeError) as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _log(
            actor=request.user, action=LicenseAuditLog.ACTION_CREATED, business=business,
            license=license_obj, new_value=f"{license_obj.code} · {duration_type} · expires {license_obj.expiry_date}",
        )
        return Response(LicenseSerializer(license_obj).data, status=status.HTTP_201_CREATED)


class LicenseDetailView(generics.RetrieveUpdateAPIView):
    """PATCH here is for non-lifecycle edits only (e.g. plan) — the code
    itself is read_only on the serializer, and status changes always go
    through the extend/revoke actions below so they're captured in the
    audit log."""
    permission_classes = [IsPlatformAdmin]
    serializer_class = LicenseSerializer
    queryset = License.objects.select_related("business", "created_by")


class LicenseExtendView(APIView):
    permission_classes = [IsPlatformAdmin]

    def post(self, request, pk):
        try:
            license_obj = License.objects.get(pk=pk)
        except License.DoesNotExist:
            return Response({"error": "License not found."}, status=status.HTTP_404_NOT_FOUND)

        duration_type = request.data.get("duration_type")
        if duration_type not in dict(License.DURATION_CHOICES):
            return Response({"error": "Invalid duration_type."}, status=status.HTTP_400_BAD_REQUEST)

        if duration_type == License.DURATION_CUSTOM:
            try:
                extra_days = int(request.data.get("duration_days"))
                assert extra_days > 0
            except (TypeError, ValueError, AssertionError):
                return Response(
                    {"error": "'duration_days' must be a positive integer for a custom extension."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        else:
            extra_days = License.DURATION_DAYS[duration_type]

        old_expiry = license_obj.expiry_date
        # Extend from whichever is later — the current expiry, or today (an
        # already-expired license extends from now, not from its stale date).
        base = max(old_expiry, timezone.localdate())
        license_obj.expiry_date = base + timedelta(days=extra_days)
        if license_obj.status == License.STATUS_EXPIRED:
            license_obj.status = License.STATUS_ACTIVE
        license_obj.save(update_fields=["expiry_date", "status"])

        _log(
            actor=request.user, action=LicenseAuditLog.ACTION_EXTENDED, business=license_obj.business,
            license=license_obj, old_value=old_expiry, new_value=license_obj.expiry_date,
        )
        return Response(LicenseSerializer(license_obj).data)


class LicenseRevokeView(APIView):
    permission_classes = [IsPlatformAdmin]

    def post(self, request, pk):
        try:
            license_obj = License.objects.get(pk=pk)
        except License.DoesNotExist:
            return Response({"error": "License not found."}, status=status.HTTP_404_NOT_FOUND)

        old_status = license_obj.status
        license_obj.status = License.STATUS_REVOKED
        license_obj.revoked_at = timezone.now()
        license_obj.save(update_fields=["status", "revoked_at"])

        _log(
            actor=request.user, action=LicenseAuditLog.ACTION_REVOKED, business=license_obj.business,
            license=license_obj, old_value=old_status, new_value=License.STATUS_REVOKED,
        )
        return Response(LicenseSerializer(license_obj).data)


class LicenseReassignView(APIView):
    """Move a PENDING (not-yet-activated) license to a different business.
    Active licenses can't be reassigned — revoke and generate a fresh one
    instead, so there's never ambiguity about which business actually used
    the premium period."""
    permission_classes = [IsPlatformAdmin]

    def post(self, request, pk):
        try:
            license_obj = License.objects.get(pk=pk)
        except License.DoesNotExist:
            return Response({"error": "License not found."}, status=status.HTTP_404_NOT_FOUND)

        if license_obj.status == License.STATUS_ACTIVE:
            return Response(
                {"error": "This license is already active — revoke it and generate a new one instead of reassigning."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        new_business_id = request.data.get("business")
        try:
            new_business = Business.objects.get(pk=new_business_id)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        old_business = license_obj.business
        license_obj.business = new_business
        license_obj.email_snapshot = new_business.email or new_business.owner.email
        license_obj.save(update_fields=["business", "email_snapshot"])

        _log(
            actor=request.user, action=LicenseAuditLog.ACTION_REASSIGNED, business=new_business,
            license=license_obj, old_value=old_business.name, new_value=new_business.name,
        )
        return Response(LicenseSerializer(license_obj).data)


class LicenseAuditLogListView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = LicenseAuditLogSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        qs = LicenseAuditLog.objects.select_related("actor", "business", "license").all()
        business_id = self.request.query_params.get("business")
        if business_id:
            qs = qs.filter(business_id=business_id)
        return qs


class ActivityLogListView(generics.ListAPIView):
    """
    Platform-wide "who created/deleted what, anywhere, just now" feed — same
    ActivityLog rows UserActivityView shows per-user, but without the pk
    scope, for Super Admin's own Activity tab. Populated by superadmin.signals
    (see ActivityLog's docstring), not per-view logging.
    """
    permission_classes = [IsPlatformAdmin]
    serializer_class = ActivityLogSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        qs = ActivityLog.objects.select_related("business", "user").all()
        params = self.request.query_params

        business_id = params.get("business")
        if business_id:
            qs = qs.filter(business_id=business_id)
        user_id = params.get("user_id")
        if user_id:
            qs = qs.filter(user_id=user_id)
        action = params.get("action")
        if action:
            qs = qs.filter(action=action)
        model_name = params.get("model")
        if model_name:
            qs = qs.filter(model_name=model_name)
        search = params.get("search", "").strip()
        if search:
            qs = qs.filter(
                models.Q(user__name__icontains=search)
                | models.Q(user__email__icontains=search)
                | models.Q(business__name__icontains=search)
                | models.Q(object_repr__icontains=search)
            )
        return qs


class BusinessFeaturePermissionsView(APIView):
    """
    GET: every registered Feature with this business's effective on/off
    state (override if one exists, else the platform default).
    PATCH {"feature_key": "reports", "enabled": false}: set or clear an
    override for one feature. enabled=null removes the override entirely,
    reverting that feature back to the platform-wide default.
    """
    permission_classes = [IsPlatformAdmin]

    def get(self, request, pk):
        try:
            business = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        overrides = {o.feature_key: o.enabled for o in BusinessFeatureOverride.objects.filter(business=business)}
        data = [
            {
                "key": f.key,
                "name": f.name,
                "platform_default": f.enabled,
                "override": overrides.get(f.key),
                "effective": overrides[f.key] if f.key in overrides else f.enabled,
            }
            for f in Feature.objects.all()
        ]
        return Response(data)

    def patch(self, request, pk):
        try:
            business = Business.objects.get(pk=pk)
        except Business.DoesNotExist:
            return Response({"error": "Business not found."}, status=status.HTTP_404_NOT_FOUND)

        key = request.data.get("feature_key")
        enabled = request.data.get("enabled")
        if not key:
            return Response({"error": "'feature_key' is required."}, status=status.HTTP_400_BAD_REQUEST)

        existing = BusinessFeatureOverride.objects.filter(business=business, feature_key=key).first()
        old_value = existing.enabled if existing else "platform default"

        if enabled is None:
            if existing:
                existing.delete()
            new_value = "platform default"
        else:
            BusinessFeatureOverride.objects.update_or_create(
                business=business, feature_key=key,
                defaults={"enabled": bool(enabled), "updated_by": request.user},
            )
            new_value = bool(enabled)

        _log(
            actor=request.user,
            action=LicenseAuditLog.ACTION_FEATURE_ENABLED if new_value is True else LicenseAuditLog.ACTION_FEATURE_DISABLED,
            business=business, old_value=f"{key}: {old_value}", new_value=f"{key}: {new_value}",
        )
        return self.get(request, pk)
