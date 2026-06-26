from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("accounts.urls")),
    path("api/inventory/", include("inventory.urls")),
    path("api/parties/", include("parties.urls")),
    path("api/sales/", include("sales.urls")),
    path("api/expenses/", include("expenses.urls")),
    path("api/banking/", include("banking.urls")),
    path("api/reports/", include("reports.urls")),
    path("api/superadmin/", include("superadmin.urls")),
    path("api/purchases/", include("purchases.urls")),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
