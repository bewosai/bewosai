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
    Called once, right after a new Business is created with a valid referral
    code. Runs the anti-abuse checks and, if they pass, grants both sides
    their reward — the referrer gets a month of whatever tier they're
    currently on (Premium stays Premium, PremiumPlus stays PremiumPlus; a
    Free referrer's reward is Premium), and the new business always gets a
    month of Premium. Always returns a Referral row (REWARDED or REJECTED)
    so there's a permanent record of what happened either way.
    """
    if referrer_business.owner_id == new_business.owner_id:
        return Referral.objects.create(
            referrer_business=referrer_business, referred_business=new_business,
            status=Referral.STATUS_REJECTED, reject_reason="Self-referral — same account on both sides.",
        )

    already_claimed = Business.objects.filter(
        referred_by=referrer_business, owner_id=new_business.owner_id,
    ).exclude(pk=new_business.pk).exists()
    if already_claimed:
        return Referral.objects.create(
            referrer_business=referrer_business, referred_business=new_business,
            status=Referral.STATUS_REJECTED, reject_reason="This account already redeemed a referral from this referrer.",
        )

    since = timezone.now() - timedelta(hours=24)
    recent_rewards = Referral.objects.filter(
        referrer_business=referrer_business, status=Referral.STATUS_REWARDED, rewarded_at__gte=since,
    ).count()
    if recent_rewards >= REFERRAL_RATE_LIMIT_PER_DAY:
        return Referral.objects.create(
            referrer_business=referrer_business, referred_business=new_business,
            status=Referral.STATUS_REJECTED, reject_reason="Referral rate limit reached for this referrer.",
        )

    with transaction.atomic():
        now = timezone.now()
        referral = Referral.objects.create(
            referrer_business=referrer_business, referred_business=new_business,
            status=Referral.STATUS_VERIFIED, verified_at=now,
        )

        referrer_plan = referrer_business.effective_plan
        referrer_reward_plan = referrer_plan if referrer_plan != Business.PLAN_FREE else Business.PLAN_PREMIUM
        referrer_sub = _extend_and_grant(business=referrer_business, plan=referrer_reward_plan, coupon_user=referrer_business.owner)
        referred_sub = _extend_and_grant(business=new_business, plan=Business.PLAN_PREMIUM, coupon_user=new_business.owner)

        referral.status = Referral.STATUS_REWARDED
        referral.rewarded_at = timezone.now()
        referral.referrer_subscription = referrer_sub
        referral.referred_subscription = referred_sub
        referral.save(update_fields=["status", "rewarded_at", "referrer_subscription", "referred_subscription"])

    return referral
