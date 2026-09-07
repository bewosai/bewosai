from django.urls import path
from . import views

urlpatterns = [
    path("subscription/", views.SubscriptionCurrentView.as_view()),
    path("apply-coupon/", views.ApplyCouponView.as_view()),
    path("referral/", views.ReferralMeView.as_view()),
]
