"""
Makes the request's authenticated user available to code that has no access
to the request at all — specifically superadmin.signals, which logs
accounts.StaffActivity from Django model signals (post_save/post_delete),
where the only thing signals ever hand you is the model instance.

Uses a ContextVar (not a plain global/threading.local) so it's safe under
both WSGI (Render's gunicorn workers) and any future async view.
"""
from contextvars import ContextVar

_current_request = ContextVar("current_request", default=None)


class CurrentUserMiddleware:
    """
    Stores the *request object itself* (not request.user's value right now),
    because DRF resolves request.user lazily — the underlying Django request
    doesn't have the real authenticated user set yet when this middleware
    runs, only once a permission class (or anything else) first touches
    `request.user` further down the view's dispatch. Reading `.user` off the
    stored request later, from inside a signal fired during the view (i.e.
    while `get_response()` is still running), sees the already-resolved user.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        token = _current_request.set(request)
        try:
            return self.get_response(request)
        finally:
            _current_request.reset(token)


def get_current_user():
    """The authenticated user making the request currently being handled, or
    None outside a request (a management command, a shell), before any
    request has resolved a user, or if the user turns out to be anonymous."""
    request = _current_request.get()
    if request is None:
        return None
    user = getattr(request, "user", None)
    return user if user is not None and getattr(user, "is_authenticated", False) else None
