from django.db.utils import DatabaseError

from rest_framework.permissions import BasePermission, SAFE_METHODS

from .utils import get_bid, get_business


def get_platform(request):
    """
    'mobile' for the Flutter app, 'desktop' for everything else (the React
    web client, API tools, etc). Both frontends send this explicitly via the
    X-Platform header rather than being sniffed from the user agent, so the
    signal is reliable — see EffectiveFeaturesView / require_feature below.
    """
    platform = (request.headers.get("X-Platform") or "").strip().lower()
    return "mobile" if platform == "mobile" else "desktop"


def require_feature(key):
    """
    Three-layer permission model, checked in order:
      1. Per-business override (superadmin.models.BusinessFeatureOverride) —
         Super Admin explicitly granting or denying this one feature to this
         one business, regardless of everything below. Checked first because
         it's the most specific rule and should always win.
      2. Super Admin platform-wide feature control — is this module even
         switched on for this business/platform right now? (Feature)
      3. Business/staff permissions — can *this* user use it? (existing
         per-view/staff-role checks, unaffected by this class)
    A Feature that's off overrides every staff permission underneath it —
    intentionally checked first and independently, so disabling e.g. Banking
    from the Super Admin dashboard immediately locks out every business on
    both Desktop and Mobile, regardless of individual staff roles.
    """

    class _RequireFeature(BasePermission):
        message = f"The '{key}' feature is currently disabled for your plan or platform."

        def has_permission(self, request, view):
            from superadmin.models import BusinessFeatureOverride, Feature

            business = get_business(request)

            if business:
                try:
                    override = BusinessFeatureOverride.objects.filter(
                        business=business, feature_key=key,
                    ).first()
                except DatabaseError:
                    override = None
                if override is not None:
                    return override.enabled

            try:
                feature = Feature.objects.filter(key=key).first()
            except DatabaseError:
                # Feature table not migrated yet on this environment — fail
                # open rather than 500 every gated endpoint.
                return True
            if feature is None:
                # Unregistered feature key — fail open rather than break
                # an endpoint because the seed data hasn't been run yet.
                return True
            platform = get_platform(request)
            return feature.is_available_on(platform, business)

    return _RequireFeature


class IsPremiumBusiness(BasePermission):
    """
    Gates Premium-only features (e.g. bulk import/export). The business must
    be resolvable from the request (see get_business) and on the Premium plan.
    """

    message = "This feature is available on the Premium plan. Upgrade to unlock it."

    def has_permission(self, request, view):
        from accounts.models import Business

        business = get_business(request)
        return bool(business and business.plan == Business.PLAN_PREMIUM)


class HasActiveSubscription(BasePermission):
    """
    Global gate: once a business's 7-day trial ends with no active license,
    every business-scoped endpoint is blocked until one is activated. Applied
    via DEFAULT_PERMISSION_CLASSES so no per-view wiring is needed — but it
    only ever looks at requests that actually resolve to a business (see
    get_business); everything else (auth, superadmin, account-level routes)
    passes straight through untouched.
    """

    message = "Your 7-day trial has ended. Enter a license code to continue."

    # Views that must stay reachable even with no active subscription — the
    # login flow itself, business switching/selection, and the license
    # activation endpoint, since a locked-out user still needs a way in.
    EXEMPT_VIEWS = {
        "SendOTPView", "VerifyOTPView", "GoogleLoginView", "LogoutView",
        "SetAccountTypeView", "TokenRefreshView", "MeView",
        "BusinessListCreateView", "BusinessDetailView",
        "LicenseMeView", "LicenseActivateView",
    }

    def has_permission(self, request, view):
        if view.__class__.__name__ in self.EXEMPT_VIEWS:
            return True
        business = get_business(request)
        if not business:
            return True
        return business.has_active_subscription


class BusinessNotArchivedForWrites(BasePermission):
    """
    Archived businesses are read-only: GET/HEAD/OPTIONS pass through untouched,
    but any mutating request (POST/PUT/PATCH/DELETE) is rejected. Requests with
    no resolvable business id (auth, superadmin, etc.) are left alone — this
    check only applies once a business is actually in scope.
    """

    message = "This business is archived and read-only. Restore it from Settings to make changes."

    # Writes to the business's own settings endpoint (restore / permanently delete
    # the archived business itself) must stay allowed even while archived.
    EXEMPT_VIEWS = {"BusinessDetailView"}

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        if view.__class__.__name__ in self.EXEMPT_VIEWS:
            return True

        bid = get_bid(request)
        if not bid:
            return True

        from accounts.models import Business

        business = Business.objects.filter(id=bid).only("status").first()
        if business and business.status == Business.STATUS_ARCHIVED:
            return False
        return True
