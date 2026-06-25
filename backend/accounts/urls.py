from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path("send-otp/", views.SendOTPView.as_view()),
    path("verify-otp/", views.VerifyOTPView.as_view()),
    path("logout/", views.LogoutView.as_view()),
    path("refresh/", TokenRefreshView.as_view()),
    path("me/", views.MeView.as_view()),
    path("businesses/", views.BusinessListCreateView.as_view()),
    path("businesses/<int:pk>/", views.BusinessDetailView.as_view()),
    path("businesses/<int:business_id>/staff/", views.StaffListView.as_view()),
    path("businesses/<int:business_id>/staff/<int:pk>/", views.StaffDetailView.as_view()),
]
