from django.urls import path
from . import views

urlpatterns = [
    path("", views.PartyListCreateView.as_view()),
    path("bulk-import/", views.PartyBulkImportView.as_view()),
    path("<int:pk>/", views.PartyDetailView.as_view()),
    path("<int:pk>/ledger/", views.PartyLedgerView.as_view()),
    path("payments/", views.PartyPaymentListCreateView.as_view()),
    path("payments/<int:pk>/", views.PartyPaymentDetailView.as_view()),
]
