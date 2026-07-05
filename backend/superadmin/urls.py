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
]
