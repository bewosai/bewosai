from rest_framework.permissions import BasePermission, SAFE_METHODS

from .utils import get_bid, get_business


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
