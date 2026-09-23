from django.conf import settings
from django.db import models
from django.db.models import Count, Q
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Business, StaffMember, User
from accounts.views import BusinessListCreateView, plan_staff_limit
from bewosai.pagination import LargePageNumberPagination
from bewosai.utils import require_business
from superadmin.views import IsPlatformAdmin
from .models import Coupon, Referral, Subscription
from .serializers import CouponSerializer, ReferralSerializer, SubscriptionSerializer
from .services import CouponError, apply_coupon


def _usage_and_limits(request, business):
    """How much of the current plan this user/business is actually using —
    the numbers the Upgrade page needs to show *why* upgrading helps, instead
    of just generic marketing copy. Reuses the exact limit constants/logic
    the enforcement views (BusinessListCreateView, StaffListView) apply, so
    this can never drift out of sync with what actually blocks a request.
    """
    owned = Business.objects.filter(owner=request.user)
    effective_plans = {b.effective_plan for b in owned}
    is_biz_unlimited = Business.PLAN_PREMIUMPLUS in effective_plans
    is_biz_premium = is_biz_unlimited or Business.PLAN_PREMIUM in effective_plans
    biz_plan_limit = BusinessListCreateView.PREMIUM_LIMIT if is_biz_premium else BusinessListCreateView.FREE_LIMIT
    biz_limit = request.user.business_limit_override if request.user.business_limit_override is not None else biz_plan_limit

    usage = {
        "business_count": owned.count(),
        "business_limit": None if is_biz_unlimited else biz_limit,
    }

    if business is not None:
        non_owner_staff = business.staff.filter(is_active=True).exclude(role=StaffMember.ROLE_OWNER).count()
        staff_limit = business.staff_limit_override if business.staff_limit_override is not None else plan_staff_limit(business.effective_plan)
        usage["staff_count"] = non_owner_staff
        usage["staff_limit"] = staff_limit

    return usage


def api_response(success, message, status_code, **extra):
    return Response({"success": success, "message": message, **extra}, status=status_code)


# ── User-facing ──────────────────────────────────────────────────────────────

class SubscriptionCurrentView(APIView):
    """Current business's effective plan plus whatever's driving it — an
    active License (unchanged system) and/or an active coupon/referral
    Subscription — so the Upgrade page can show one honest picture instead
    of just the raw `plan` field."""

    def get(self, request):
        business = require_business(request)
        sub = business.active_referral_subscription
        return Response({
            "effective_plan": business.effective_plan,
            "base_plan": business.plan,
            "active_license": bool(business.active_license),
            "license_expiry": business.active_license.expiry_date if business.active_license else None,
            "active_subscription": SubscriptionSerializer(sub).data if sub else None,
            **_usage_and_limits(request, business),
        })


class ApplyCouponView(APIView):
    throttle_scope = "otp_verify"

    def post(self, request):
        business = require_business(request)
        if business.owner_id != request.user.id:
            return api_response(False, "Only the business owner can apply a coupon.", status.HTTP_403_FORBIDDEN)
        code = (request.data.get("code") or "").strip()
        if not code:
            return api_response(False, "Enter a coupon code.", status.HTTP_400_BAD_REQUEST)

        try:
            subscription = apply_coupon(code=code, user=request.user, business=business)
        except CouponError as exc:
            return api_response(False, str(exc), status.HTTP_400_BAD_REQUEST)

        return api_response(
            True, f"Coupon applied — {subscription.get_plan_display()} active until {subscription.end_date}.",
            status.HTTP_200_OK, subscription=SubscriptionSerializer(subscription).data,
        )


class ReferralMeView(APIView):
    """Everything the Refer & Earn page needs: this business's own code/link,
    how many successful referrals it has, and the reward history."""

    def get(self, request):
        business = require_business(request)
        rewards = Referral.objects.filter(
            referrer_business=business, status=Referral.STATUS_REWARDED,
        ).select_related("referred_business")

        return Response({
            "referral_code": business.referral_code,
            "referral_link": f"{settings.FRONTEND_URL}/r/{business.referral_code}",
            "total_referrals": rewards.count(),
            "rewards": ReferralSerializer(
                Referral.objects.filter(referrer_business=business).order_by("-registered_at")[:50], many=True,
            ).data,
        })


# ── Superadmin: coupons ───────────────────────────────────────────────────────

class CouponListCreateView(generics.ListCreateAPIView):
    """Superadmin coupon table + create form. Mirrors
    superadmin.views.LicenseListView/LicenseGenerateView's shape (search,
    plan/status filters, LargePageNumberPagination) so the two admin screens
    feel like the same system even though the underlying models are kept
    separate."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = CouponSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        qs = Coupon.objects.select_related("user", "used_for_business", "created_by").all()
        params = self.request.query_params

        plan = params.get("plan")
        if plan:
            qs = qs.filter(plan=plan)

        search = params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(code__icontains=search)
                | Q(user__email__icontains=search)
                | Q(user__name__icontains=search)
                | Q(user__phone__icontains=search)
            )

        status_filter = params.get("status")
        if status_filter:
            # computed_status is a Python property, not a DB column — filter
            # in Python after narrowing with the cheap DB-level signals
            # (is_active/is_used) so this doesn't have to fetch everything.
            ids = [c.id for c in qs if c.computed_status == status_filter]
            qs = qs.filter(id__in=ids)

        return qs

    def create(self, request, *args, **kwargs):
        user_id = request.data.get("user")
        plan = request.data.get("plan")
        end_date_raw = request.data.get("end_date")
        if not user_id or not plan or not end_date_raw:
            return api_response(False, "'user', 'plan', and 'end_date' are required.", status.HTTP_400_BAD_REQUEST)
        if plan not in dict(Coupon.PLAN_CHOICES):
            return api_response(False, "Invalid plan.", status.HTTP_400_BAD_REQUEST)

        # request.data hands back plain strings, not date objects — parse
        # explicitly rather than relying on Django to coerce them, since
        # Coupon.generate() creates the row directly (no serializer in the
        # way) and computed_status compares these against a real date the
        # moment the response is built.
        start_date_raw = request.data.get("start_date")
        start_date = parse_date(start_date_raw) if start_date_raw else timezone.localdate()
        end_date = parse_date(end_date_raw)
        if start_date is None or end_date is None:
            return api_response(False, "Dates must be in YYYY-MM-DD format.", status.HTTP_400_BAD_REQUEST)
        if end_date < start_date:
            return api_response(False, "End date can't be before start date.", status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return api_response(False, "User not found.", status.HTTP_404_NOT_FOUND)

        coupon = Coupon.generate(
            user=user, plan=plan, start_date=start_date, end_date=end_date,
            source=Coupon.SOURCE_ADMIN, created_by=request.user,
        )
        return Response(CouponSerializer(coupon).data, status=status.HTTP_201_CREATED)


class CouponDeactivateView(APIView):
    """Covers both "Disable" and "Cancel" from the spec as one action — a
    disabled coupon's computed_status already reads CANCELLED, so there's no
    separate state to model."""

    permission_classes = [IsPlatformAdmin]

    def post(self, request, pk):
        coupon = Coupon.objects.filter(pk=pk).first()
        if not coupon:
            return api_response(False, "Coupon not found.", status.HTTP_404_NOT_FOUND)
        coupon.is_active = False
        coupon.save(update_fields=["is_active"])
        return Response(CouponSerializer(coupon).data)


# ── Superadmin: referrals ─────────────────────────────────────────────────────

class ReferralAdminListView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = ReferralSerializer
    pagination_class = LargePageNumberPagination

    def get_queryset(self):
        qs = Referral.objects.select_related(
            "referrer_business", "referrer_business__owner", "referred_business", "referred_business__owner",
        ).all()
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        search = self.request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(referrer_business__name__icontains=search)
                | Q(referred_business__name__icontains=search)
                | Q(referrer_business__owner__email__icontains=search)
            )
        return qs


class ReferralStatsView(APIView):
    """Powers Super Admin's "Referral Management" summary: totals, and the
    top referring businesses by successful (REWARDED) referral count."""

    permission_classes = [IsPlatformAdmin]

    def get(self, request):
        totals = Referral.objects.aggregate(
            total=Count("id"),
            verified=Count("id", filter=Q(status__in=[Referral.STATUS_VERIFIED, Referral.STATUS_REWARDED])),
            rewarded=Count("id", filter=Q(status=Referral.STATUS_REWARDED)),
            rejected=Count("id", filter=Q(status=Referral.STATUS_REJECTED)),
        )
        top = (
            Referral.objects.filter(status=Referral.STATUS_REWARDED)
            .values("referrer_business_id", "referrer_business__name")
            .annotate(count=Count("id"))
            .order_by("-count")[:10]
        )
        return Response({
            **totals,
            "top_referrers": [
                {"business_id": row["referrer_business_id"], "business_name": row["referrer_business__name"], "count": row["count"]}
                for row in top
            ],
        })
