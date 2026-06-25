from django.urls import path
from . import views

urlpatterns = [
    path("stats/", views.PlatformStatsView.as_view()),
    path("businesses/", views.BusinessManagementView.as_view()),
    path("businesses/<int:pk>/action/", views.BusinessActionView.as_view()),
    path("users/", views.UserManagementView.as_view()),
    path("login-activity/", views.LoginActivityView.as_view()),
    path("announcements/", views.AnnouncementListCreateView.as_view()),
    path("tickets/", views.TicketListView.as_view()),
    path("tickets/<int:pk>/", views.TicketDetailView.as_view()),
    path("support/", views.SubmitTicketView.as_view()),
]
