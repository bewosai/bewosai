from django.apps import AppConfig


class SuperadminConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "superadmin"

    def ready(self):
        from . import signals
        signals.connect()
        from bewosai import feature_cache
        feature_cache.connect()
