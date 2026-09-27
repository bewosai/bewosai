"""
Core billing logic — kept out of views.py so both the user-facing
"apply coupon" endpoint and the referral auto-reward path share exactly one
implementation of "how does redeeming something actually grant a
Subscription," rather than two subtly different copies.
"""
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from accounts.models import Business
from .models import Coupon, Referral, Subscription

REFERRAL_REWARD_DAYS = 30
# A referral code can only be redeemed by an account at most this old.
NEW_USER_DAYS = 30
# Anti-abuse: a single referrer can't be rewarded more than this many times
# in a rolling 24h window — catches a burst of farmed signups without
# penalizing a business that's just genuinely popular that week.
REFERRAL_RATE_LIMIT_PER_DAY = 20


class CouponError(Exception):
    """Raised for any coupon-apply failure the view should turn into a 400/403/404."""


def apply_coupon(*, code, user, business):
    """
    Redeems `code` for `business` on behalf of `user`. Validates the coupon
    belongs to this exact user (not just this business — the spec's own
    "don't let someone else use my code" rule) and is currently ACTIVE, then
    creates the Subscription and marks the coupon used. Wrapped in
    transaction.atomic() + select_for_update so two simultaneous applies of
    the same coupon can't both succeed.
    """
    with transaction.atomic():
        coupon = Coupon.objects.select_for_update().filter(code=code.strip().upper()).first()
        if not coupon:
            raise CouponError("Invalid coupon code.")
        if coupon.user_id != user.id:
            raise CouponError("This coupon is not assigned to your account.")
        if coupon.computed_status != "ACTIVE":
            status_messages = {
                "USED": "This coupon has already been used.",
                "EXPIRED": "This coupon has expired.",
                "CANCELLED": "This coupon has been cancelled.",
            }
            raise CouponError(status_messages.get(coupon.computed_status, "This coupon can't be used."))

        subscription = Subscription.objects.create(
            business=business, user=user, plan=coupon.plan, status=Subscription.STATUS_ACTIVE,
            start_date=coupon.start_date, end_date=coupon.end_date,
            source=coupon.source, coupon=coupon,
        )
        coupon.is_used = True
        coupon.used_at = timezone.now()
        coupon.used_for_business = business
        coupon.save(update_fields=["is_used", "used_at", "used_for_business"])

    return subscription


def _extend_and_grant(*, business, plan, coupon_user, days=REFERRAL_REWARD_DAYS):
    """+`days` on top of whichever is later — this business's current active
    subscription expiry, or today. Never blindly resets the expiry, so a
    referral reward genuinely adds time instead of overwriting a longer
    entitlement someone already had (e.g. from a real purchase)."""
    today = timezone.localdate()
    current = business.active_referral_subscription
    base = current.end_date if current and current.end_date >= today else today
    end_date = base + timedelta(days=days)

    coupon = Coupon.generate(
        user=coupon_user, plan=plan, start_date=today, end_date=end_date,
        source=Coupon.SOURCE_REFERRAL, created_by=None,
    )
    coupon.is_used = True
    coupon.used_at = timezone.now()
    coupon.used_for_business = business
    coupon.save(update_fields=["is_used", "used_at", "used_for_business"])

    return Subscription.objects.create(
        business=business, user=coupon_user, plan=plan, status=Subscription.STATUS_ACTIVE,
        start_date=today, end_date=end_date, source=Coupon.SOURCE_REFERRAL, coupon=coupon,
    )


def process_referral(*, new_business, referrer_business):
    """
    Called once when a business is created with a referral code, or when its
    owner types a referral code into "Have a coupon?". Referral codes are for
    *new users only*: the redeeming account must be under NEW_USER_DAYS old
    and must never have used a referral before. If the checks pass and the
    new user has verified their sign-in (emailed code / Google), both sides
    get REFERRAL_REWARD_DAYS: the referrer a month of whatever tier they're
    currently on (a Free referrer's reward is Premium), the new business a
    month of Premium. Not verified yet → the Referral waits as REGISTERED and
    reward_waiting_referrals() pays it out at their first verified sign-in.
    Always returns a Referral row, so there's a permanent record either way.
    """
    def reject(reason):
        return Referral.objects.create(
            referrer_business=referrer_business, referred_business=new_business,
            status=Referral.STATUS_REJECTED, reject_reason=reason,
        )

    owner = new_business.owner
    if referrer_business.owner_id == owner.id:
        return reject("Self-referral — same account on both sides.")

    if owner.created_at and owner.created_at < timezone.now() - timedelta(days=NEW_USER_DAYS):
        return reject("Referral codes are for new accounts only.")

    used_before = Referral.objects.filter(referred_business__owner=owner).exclude(
        status=Referral.STATUS_REJECTED,
    ).exclude(referred_business=new_business).exists()
    if used_before:
        return reject("This account has already used a referral code.")

    since = timezone.now() - timedelta(hours=24)
    recent_rewards = Referral.objects.filter(
        referrer_business=referrer_business, status=Referral.STATUS_REWARDED, rewarded_at__gte=since,
    ).count()
    if recent_rewards >= REFERRAL_RATE_LIMIT_PER_DAY:
        return reject("Referral rate limit reached for this referrer.")

    referral = Referral.objects.create(
        referrer_business=referrer_business, referred_business=new_business,
        status=Referral.STATUS_REGISTERED,
    )
    if owner.is_verified:
        _reward(referral)
    return referral


def reward_waiting_referrals(user):
    """Pays out any referral that was waiting for `user` to verify their
    sign-in. Called right after a verified email-code or Google login."""
    for referral in Referral.objects.filter(
        referred_business__owner=user, status=Referral.STATUS_REGISTERED,
    ).select_related("referrer_business__owner", "referred_business__owner"):
        _reward(referral)


def _reward(referral):
    """+REFERRAL_REWARD_DAYS for both sides of a REGISTERED referral."""
    referrer_business = referral.referrer_business
    new_business = referral.referred_business
    with transaction.atomic():
        now = timezone.now()
        referral.status = Referral.STATUS_VERIFIED
        referral.verified_at = now
        referral.save(update_fields=["status", "verified_at"])

        referrer_plan = referrer_business.effective_plan
        referrer_reward_plan = referrer_plan if referrer_plan != Business.PLAN_FREE else Business.PLAN_PREMIUM
        referrer_sub = _extend_and_grant(business=referrer_business, plan=referrer_reward_plan, coupon_user=referrer_business.owner)
        referred_sub = _extend_and_grant(business=new_business, plan=Business.PLAN_PREMIUM, coupon_user=new_business.owner)

        referral.status = Referral.STATUS_REWARDED
        referral.rewarded_at = timezone.now()
        referral.referrer_subscription = referrer_sub
        referral.referred_subscription = referred_sub
        referral.save(update_fields=["status", "rewarded_at", "referrer_subscription", "referred_subscription"])
