import logging

from django.conf import settings

logger = logging.getLogger(__name__)


def grant_platform_admin_if_listed(user):
    """
    Makes `user` a platform admin if their email is in settings.PLATFORM_ADMIN_EMAILS.

    Only ever called for an account that has *proved* the address — right after a
    correct emailed code or a verified Google sign-in, or on a request carrying a
    valid JWT for a verified account — never on a bare claim of an email address.
    Returns True if it just granted admin.
    """
    email = (user.email or "").strip().lower()
    if not email or user.is_platform_admin or email not in settings.PLATFORM_ADMIN_EMAILS:
        return False
    user.is_platform_admin = True
    user.save(update_fields=["is_platform_admin"])
    logger.warning("Granted platform admin to %s via PLATFORM_ADMIN_EMAILS", email)
    return True
