"""Shared request-context helpers used across all apps."""
import ipaddress

from rest_framework.exceptions import ValidationError

from accounts.models import Business


def client_ip(request):
    """The caller's real IP. On Render (and any proxy/CDN) REMOTE_ADDR is the
    proxy's own address, so every login was being recorded with the same
    internal IP — the real client is the first entry of X-Forwarded-For.
    Validated, because the header is client-supplied text and a garbage value
    would crash the insert on Postgres' inet column; falls back to REMOTE_ADDR."""
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
    first = forwarded.split(",")[0].strip()
    if first:
        try:
            return str(ipaddress.ip_address(first))
        except ValueError:
            pass
    return request.META.get("REMOTE_ADDR") or None

# One-character/common-swap typos of the big email providers. SMTP delivery
# is fire-and-forget from Django's point of view — send_mail() reports
# success as soon as the relay *accepts* the message, even if the domain is
# a typo'd real domain that isn't the sender's mailbox (e.g. "gamil.com").
# The user then sees "OTP sent" and never receives anything, with no error
# anywhere to explain why — so we catch the common ones before sending.
_EMAIL_DOMAIN_TYPOS = {
    "gamil.com": "gmail.com", "gmial.com": "gmail.com", "gmai.com": "gmail.com",
    "gmal.com": "gmail.com", "gnail.com": "gmail.com", "gmaill.com": "gmail.com",
    "gmail.co": "gmail.com", "gmail.cm": "gmail.com", "gmail.con": "gmail.com",
    "yaho.com": "yahoo.com", "yahooo.com": "yahoo.com", "yaoo.com": "yahoo.com",
    "yahoo.co": "yahoo.com", "yahoo.con": "yahoo.com",
    "hotmial.com": "hotmail.com", "hotmil.com": "hotmail.com", "hotmai.com": "hotmail.com",
    "homail.com": "hotmail.com", "hotmail.co": "hotmail.com", "hotmail.con": "hotmail.com",
    "outlok.com": "outlook.com", "outllok.com": "outlook.com", "outlook.co": "outlook.com",
    "iclould.com": "icloud.com", "iclouds.com": "icloud.com",
}


def suggest_email_typo_fix(email):
    """Returns the corrected email if its domain is a known common typo,
    else None. Callers should reject the request and surface the suggestion
    rather than silently "sending" to a domain that isn't the real one."""
    if "@" not in email:
        return None
    local, _, domain = email.rpartition("@")
    fix = _EMAIL_DOMAIN_TYPOS.get(domain.lower())
    return f"{local}@{fix}" if fix else None


def mask_email(email):
    """'jane.doe@example.com' -> 'ja***@example.com' — enough for a user to
    recognize their own address in a message without fully exposing it to
    whoever happened to type in a phone number that resolves to it."""
    local, _, domain = email.partition("@")
    visible = local[:2] if len(local) > 2 else local[:1]
    return f"{visible}***@{domain}" if domain else f"{visible}***"


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

    Remembered on the request: the permission classes and the view each ask
    for it, and repeating the same lookup costs a database round trip each time.
    """
    bid = get_bid(request)
    if not bid:
        return None
    key = (str(bid), getattr(request.user, "pk", None))
    cached = getattr(request, "_business_lookup", None)
    if cached is not None and cached[0] == key:
        return cached[1]
    business = (
        Business.objects.filter(
            id=bid,
            staff__user=request.user,
            staff__is_active=True,
            status=Business.STATUS_ACTIVE,
        )
        .first()
    )
    try:
        request._business_lookup = (key, business)
    except AttributeError:
        pass
    return business


def require_business(request):
    """
    Like get_business(), but raises a 400 instead of returning None — for use
    in perform_create/perform_update where a resolvable, membership-validated
    business is mandatory before writing anything.
    """
    business = get_business(request)
    if business is None:
        raise ValidationError("No business selected or access denied.")
    return business


def sync_bank_transaction(*, reference, bank_account, transaction_type, amount, date, description, created_by):
    """
    Keeps a Sale/Purchase/PartyPayment's real bank movement in sync with a
    BankTransaction row, so marking something "Bank Transfer" (or eSewa/
    Khalti/...) actually affects that account's balance and shows up on its
    Bank Statement — previously payment_method was purely cosmetic, with no
    connection at all to the Banking module.

    [reference] must be a value that's unique to the owning record across the
    whole system (e.g. f"SALE-{sale.id}") — used as the sole lookup key, so
    calling this again for the same record updates the same transaction
    instead of creating duplicates, and calling it with bank_account=None or
    amount<=0 removes any transaction that previously existed for it (e.g.
    the payment method was switched back to Cash, or paid_amount reset).
    """
    from banking.models import BankTransaction

    if not bank_account or not amount or amount <= 0:
        BankTransaction.objects.filter(reference=reference).delete()
        return

    BankTransaction.objects.update_or_create(
        reference=reference,
        defaults={
            "account": bank_account,
            "transaction_type": transaction_type,
            "amount": amount,
            "date": date,
            "description": description,
            "created_by": created_by,
        },
    )
