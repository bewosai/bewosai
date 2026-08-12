from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path("send-otp/", views.SendOTPView.as_view()),
    path("verify-otp/", views.VerifyOTPView.as_view()),
    path("google-login/", views.GoogleLoginView.as_view()),
    path("logout/", views.LogoutView.as_view()),
    path("set-account-type/", views.SetAccountTypeView.as_view()),
    path("refresh/", TokenRefreshView.as_view()),
    path("me/", views.MeView.as_view()),
    path("businesses/", views.BusinessListCreateView.as_view()),
    path("businesses/<int:pk>/", views.BusinessDetailView.as_view()),
    path("businesses/<int:pk>/close-fiscal-year/", views.CloseFiscalYearView.as_view()),
    path("businesses/<int:business_id>/staff/", views.StaffListView.as_view()),
    path("businesses/<int:business_id>/staff/<int:pk>/", views.StaffDetailView.as_view()),
    path("staff-activity/", views.StaffActivityView.as_view(), name="staff-activity"),
]
