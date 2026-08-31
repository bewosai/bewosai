from django.urls import path
from . import views

urlpatterns = [
    # Platform overview (admin only)
    path("stats/", views.PlatformStatsView.as_view()),

    # Business management (admin only)
    path("businesses/", views.BusinessManagementView.as_view()),
    path("businesses/<int:pk>/action/", views.BusinessActionView.as_view()),
    path("businesses/<int:pk>/", views.BusinessEditDeleteView.as_view()),
    path("businesses/<int:pk>/data/", views.BusinessDataView.as_view()),

    # User management (admin only)
    path("users/create/", views.UserCreateAdminView.as_view()),   # before <pk> pattern
    path("users/", views.UserManagementView.as_view()),
    path("users/<int:pk>/action/", views.UserActionView.as_view()),
    path("users/<int:pk>/delete/", views.UserDeleteAdminView.as_view()),
    path("users/<int:pk>/activity/", views.UserActivityView.as_view()),
    path("users/<int:pk>/summary/", views.UserSummaryView.as_view()),

    # Login activity (admin only)
    path("login-activity/", views.LoginActivityView.as_view()),

    # Announcements
    path("announcements/", views.AnnouncementListCreateView.as_view()),
    path("announcements/active/", views.ActiveAnnouncementsView.as_view()),  # before <pk>
    path("announcements/<int:pk>/", views.AnnouncementDetailView.as_view()),

    # Support tickets
    path("tickets/", views.TicketListView.as_view()),
    path("tickets/<int:pk>/", views.TicketDetailView.as_view()),
    path("support/", views.SubmitTicketView.as_view()),

    # Feature management (admin only) — public effective-map endpoint lives
    # at /api/features/ (see bewosai/urls.py), not here, since every business
    # user needs to read it, not just platform admins.
    path("features/", views.FeatureManagementListView.as_view()),
    path("features/<slug:key>/toggle/", views.FeatureToggleView.as_view()),

    # Licensing (admin only)
    path("licenses/", views.LicenseListView.as_view()),
    path("licenses/years/", views.LicenseYearsView.as_view()),  # before <pk>
    path("licenses/generate/", views.LicenseGenerateView.as_view()),
    path("licenses/audit-log/", views.LicenseAuditLogListView.as_view()),
    path("licenses/<int:pk>/", views.LicenseDetailView.as_view()),
    path("licenses/<int:pk>/extend/", views.LicenseExtendView.as_view()),
    path("licenses/<int:pk>/revoke/", views.LicenseRevokeView.as_view()),
    path("licenses/<int:pk>/reassign/", views.LicenseReassignView.as_view()),
    path("businesses/<int:pk>/features/", views.BusinessFeaturePermissionsView.as_view()),
]
