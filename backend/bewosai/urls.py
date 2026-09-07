from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

from superadmin.views import EffectiveFeaturesView

urlpatterns = [
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
