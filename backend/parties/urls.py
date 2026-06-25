from django.urls import path
from . import views

urlpatterns = [
    path("", views.PartyListCreateView.as_view()),
    path("<int:pk>/", views.PartyDetailView.as_view()),
    path("payments/", views.PartyPaymentListCreateView.as_view()),
]
