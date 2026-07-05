"""Shared request-context helpers used across all apps."""
from accounts.models import Business


def get_bid(request):
    """
    Return the business ID from whichever source is present.
    Flutter app sends X-Business-ID header; web client sends ?business= query param.
    POST body is also accepted as fallback.
    """
    return (
        request.headers.get("X-Business-ID")
        or request.query_params.get("business")
        or request.data.get("business")
    )


def get_business(request):
    """
    Return the Business the request is scoped to, validating that the
    authenticated user is an active staff member of that business.
    Returns None if no valid business is found.
    """
    bid = get_bid(request)
    if not bid:
        return None
    return (
        Business.objects.filter(
            id=bid,
            staff__user=request.user,
            staff__is_active=True,
            status=Business.STATUS_ACTIVE,
        )
        .first()
    )
