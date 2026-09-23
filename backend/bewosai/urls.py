from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

from superadmin.views import EffectiveFeaturesView


def _health(request):
    """The bare root URL — nothing calls this (the website and app always hit
    /api/... directly), but visiting it in a browser used to show a plain
    "Not Found" that looked like the service was broken, when it was just
    that no view existed at "/" at all. This also works as a Render Health
    Check Path (Settings -> Health Checks), which needs a URL that always
    returns 200 when the service is actually up."""
    return JsonResponse({"status": "ok", "service": "bewosai-backend"})


urlpatterns = [
    path("", _health),
    path("admin/", admin.site.urls),
    # API docs
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
    # Feature availability — public to any authenticated user (not just
    # platform admins), since every business/staff account must read it to
    # know what's currently enabled. Admin CRUD lives under /api/superadmin/.
    path("api/features/", EffectiveFeaturesView.as_view()),
    # App routes
    path("api/auth/", include("accounts.urls")),
    path("api/staff/", include("accounts.staff_urls")),
    path("api/inventory/", include("inventory.urls")),
    path("api/parties/", include("parties.urls")),
    path("api/sales/", include("sales.urls")),
    path("api/expenses/", include("expenses.urls")),
    path("api/banking/", include("banking.urls")),
    path("api/reports/", include("reports.urls")),
    path("api/superadmin/", include("superadmin.urls")),
    path("api/purchases/", include("purchases.urls")),
    path("api/billing/", include("billing.urls")),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
