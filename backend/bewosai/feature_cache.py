"""
The Super Admin feature switches (superadmin.Feature) and per-business
overrides (BusinessFeatureOverride), kept in memory for a few seconds.

require_feature() runs on nearly every request, and each of its two lookups is
a database round trip — the biggest fixed cost of every page. These rows only
change when Super Admin flips a switch, so a short cache is safe: any save or
delete clears it at once in this process (see connect()), and other server
processes pick the change up within FEATURE_CACHE_SECONDS.
"""
from django.conf import settings
from django.core.cache import cache

_ALL = "feature_cache:all"


def _overrides_key(business_id):
    return f"feature_cache:overrides:{business_id}"


def _ttl():
    return getattr(settings, "FEATURE_CACHE_SECONDS", 0)


def all_features():
    """{key: Feature} for every registered feature."""
    from superadmin.models import Feature

    ttl = _ttl()
    if ttl:
        cached = cache.get(_ALL)
        if cached is not None:
            return cached
    features = {f.key: f for f in Feature.objects.all()}
    if ttl:
        cache.set(_ALL, features, ttl)
    return features


def business_overrides(business_id):
    """{feature_key: enabled} for the explicit overrides on one business."""
    from superadmin.models import BusinessFeatureOverride

    ttl = _ttl()
    if ttl:
        cached = cache.get(_overrides_key(business_id))
        if cached is not None:
            return cached
    overrides = dict(
        BusinessFeatureOverride.objects.filter(business_id=business_id).values_list("feature_key", "enabled")
    )
    if ttl:
        cache.set(_overrides_key(business_id), overrides, ttl)
    return overrides


def _forget_features(**_):
    cache.delete(_ALL)


def _forget_overrides(instance, **_):
    cache.delete(_overrides_key(instance.business_id))


def connect():
    """Called from SuperadminConfig.ready()."""
    from django.apps import apps
    from django.db.models.signals import post_delete, post_save

    feature = apps.get_model("superadmin", "Feature")
    override = apps.get_model("superadmin", "BusinessFeatureOverride")
    for signal in (post_save, post_delete):
        signal.connect(_forget_features, sender=feature, dispatch_uid=f"feature_cache_{signal}_feature")
        signal.connect(_forget_overrides, sender=override, dispatch_uid=f"feature_cache_{signal}_override")
