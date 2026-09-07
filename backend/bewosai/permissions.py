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


_ACTION_BY_METHOD = {
    "GET": "view", "HEAD": "view", "OPTIONS": "view",
    "POST": "create",
    "PUT": "edit", "PATCH": "edit",
    "DELETE": "delete",
}


def require_staff_permission(module_key):
    """
    Per-staff-member, per-action module access — the layer require_feature's
    docstring calls out as "existing per-view/staff-role checks", which
    didn't actually exist anywhere outside the Staff screens themselves
    until now: every active staff member had full read/write access to
    every module regardless of role.

    `StaffMember.permissions` already stores exactly this shape — it's the
    same {module: {view, create, edit, delete}} matrix the Staff invite/edit
    UI already builds and saves (client/src/pages/StaffPage.jsx's
    PermissionMatrix) — it just wasn't enforced anywhere. `module_key` must
    match that UI's module keys (sales, purchases, expenses, inventory,
    parties, payments, banking, staff, reports), not the unrelated Super
    Admin feature keys (e.g. "pos"/"staff_management") checked by
    require_feature above.

    A staff member with no entry for `module_key` at all — every existing
    staff member before this shipped, since it was never enforced — defaults
    to fully allowed, so nobody loses access they already had. Once the
    owner has actually configured a module for someone, an explicit `False`
    on the specific action (view/create/edit/delete, chosen by the request's
    HTTP method) denies just that. The business owner (by `Business.owner`
    or by holding the OWNER role) always bypasses this — they can't lock
    themselves out of their own business.
    """

    class _RequireStaffPermission(BasePermission):
        message = "Your account doesn't have access to this. Ask the business owner to enable it for you."

        def has_permission(self, request, view):
            from accounts.models import StaffMember

            business = get_business(request)
            if not business:
                # No resolvable business — some other permission class
                # (membership, subscription) is the right one to reject
                # this request; don't produce a second, misleading error.
                return True
            if business.owner_id == request.user.id:
                return True

            staff = business.staff.filter(user=request.user, is_active=True).first()
            if not staff or staff.role == StaffMember.ROLE_OWNER:
                return True

            module_perms = staff.permissions.get(module_key)
            if not isinstance(module_perms, dict):
                return True

            action = _ACTION_BY_METHOD.get(request.method, "view")
            return module_perms.get(action, True) is not False

    return _RequireStaffPermission


class IsPremiumBusiness(BasePermission):
    """
    Gates Premium-only features (e.g. bulk import/export). The business must
    be resolvable from the request (see get_business) and on the Premium plan.
    """

    message = "This feature is available on the Premium plan. Upgrade to unlock it."

    def has_permission(self, request, view):
        from accounts.models import Business

        business = get_business(request)
        return bool(business and business.effective_plan != Business.PLAN_FREE)


class HasActiveSubscription(BasePermission):
    """
    Global gate: once a business's 120-day trial ends with no active license
    and no Super-Admin-granted platform trial (see Business.has_access),
    every business-scoped endpoint is blocked until one is activated. Applied
    via DEFAULT_PERMISSION_CLASSES so no per-view wiring is needed — but it
    only ever looks at requests that actually resolve to a business (see
    get_business); everything else (auth, superadmin, account-level routes)
    passes straight through untouched.
    """

    message = "Your 120-day trial has ended. Enter a license code to continue."

    # Views that must stay reachable even with no active subscription — the
    # login flow itself, business switching/selection, and the license
    # activation endpoint, since a locked-out user still needs a way in.
    EXEMPT_VIEWS = {
        "SendOTPView", "VerifyOTPView", "GoogleLoginView", "LogoutView",
        "SetAccountTypeView", "TokenRefreshView", "MeView",
        "BusinessListCreateView", "BusinessDetailView",
        "LicenseMeView", "LicenseActivateView",
        # Refer & Earn / Upgrade Plan — a locked-out (trial-expired) business
        # is exactly who needs to reach these, same reasoning as the License
        # views above.
        "SubscriptionCurrentView", "ApplyCouponView", "ReferralMeView",
    }

    def has_permission(self, request, view):
        if view.__class__.__name__ in self.EXEMPT_VIEWS:
            return True
        business = get_business(request)
        if not business:
            return True
        return business.has_access(get_platform(request))


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
