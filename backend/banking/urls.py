from django.urls import path
from . import views

urlpatterns = [
    path("accounts/", views.BankAccountListCreateView.as_view()),
    path("accounts/<int:pk>/", views.BankAccountDetailView.as_view()),
    path("transactions/", views.BankTransactionListCreateView.as_view()),
    path("transactions/<int:pk>/", views.BankTransactionDetailView.as_view()),
]
