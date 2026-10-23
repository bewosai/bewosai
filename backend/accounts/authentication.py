from datetime import timedelta

from django.utils import timezone
from rest_framework_simplejwt.authentication import JWTAuthentication

from .admin_access import grant_platform_admin_if_listed

# Refreshing the timestamp on every request would be a write per API call; once
# every few minutes is plenty for "last seen" / "online now".
ACTIVITY_WRITE_INTERVAL = timedelta(minutes=5)


def request_platform(request):
    """'app' for the phone app, 'web' for the website (their X-Platform header),
    '' for anything else (API tools, tests)."""
    platform = (request.headers.get("X-Platform") or "").strip().lower()
    return {"mobile": "app", "web": "web"}.get(platform, "")


class TrackedJWTAuthentication(JWTAuthentication):
    """
    Normal JWT authentication that also records when each account was last
    active, so Super Admin sees who is really using the app — not just who
    signed in most recently (sessions last up to 30 days).
    """

    def authenticate(self, request):
        result = super().authenticate(request)
        if result is not None:
            user = result[0]
            # A listed email that was already signed in when it was added to
            # PLATFORM_ADMIN_EMAILS becomes admin on its next request — no need to
            # sign out and back in. Verified accounts only.
            if user.is_verified and not user.is_platform_admin:
                grant_platform_admin_if_listed(user)
            now = timezone.now()
            last = user.last_active_at
            platform = request_platform(request) or user.last_active_platform
            # Also on a switch between website and app, so "last used on" is
            # right straight away rather than after the next interval.
            if last is None or now - last >= ACTIVITY_WRITE_INTERVAL or platform != user.last_active_platform:
                # A targeted UPDATE (not user.save()) so it can't overwrite anything else,
                # and a failure to record activity must never fail the request itself.
                try:
                    type(user).objects.filter(pk=user.pk).update(last_active_at=now, last_active_platform=platform)
                    user.last_active_at = now
                    user.last_active_platform = platform
                except Exception:
                    pass
        return result
