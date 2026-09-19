"""
Every model registered in Django admin must actually render its changelist —
registering one with a typo'd list_display/search field doesn't show up as an
error until someone opens that exact page. Also checks a superuser can log in
at all, since accounts.User is a custom, password-optional model.
"""
from django.contrib import admin
from django.test import TestCase, Client

from accounts.models import User


class DjangoAdminSiteTests(TestCase):
    def setUp(self):
        self.superuser = User.objects.create_superuser(email="root@example.com", name="Root", password="a-strong-password-123")
        self.client = Client()

    def test_a_superuser_account_can_be_created_and_used_to_log_in(self):
        self.assertTrue(self.superuser.is_staff)
        self.assertTrue(self.superuser.is_superuser)
        self.assertTrue(self.superuser.is_platform_admin)
        ok = self.client.login(username="root@example.com", password="a-strong-password-123")
        self.assertTrue(ok, "createsuperuser account could not log in to /admin/")

    def test_admin_index_loads(self):
        self.client.force_login(self.superuser)
        res = self.client.get("/admin/")
        self.assertEqual(res.status_code, 200)

    def test_every_registered_model_changelist_renders(self):
        self.client.force_login(self.superuser)
        failures = []
        for model, model_admin in admin.site._registry.items():
            url = f"/admin/{model._meta.app_label}/{model._meta.model_name}/"
            res = self.client.get(url)
            if res.status_code != 200:
                failures.append(f"{model._meta.label} -> {url} returned {res.status_code}")
        self.assertEqual(failures, [], "\n".join(failures))

    def test_every_app_model_is_actually_registered_or_shown_as_an_inline(self):
        """Catches a model added later and forgotten entirely in admin.py — the
        whole point of "show all app detail" is that nothing is missing. A pure
        line-item model (SaleItem, PaymentAllocation, ...) is fine as an inline
        on its already-registered parent — the standard Django pattern, and
        genuinely visible there — rather than needing its own top-level page."""
        from django.apps import apps

        our_apps = {
            "accounts", "inventory", "parties", "sales", "purchases",
            "expenses", "banking", "superadmin", "billing",
        }
        inlined_models = {
            inline.model
            for model_admin in admin.site._registry.values()
            for inline in getattr(model_admin, "inlines", [])
        }
        missing = [
            m for m in apps.get_models()
            if m._meta.app_label in our_apps
            and m not in admin.site._registry
            and m not in inlined_models
        ]
        self.assertEqual(missing, [], f"Not shown anywhere in admin: {[m._meta.label for m in missing]}")
