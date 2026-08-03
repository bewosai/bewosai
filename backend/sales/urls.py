from django.urls import path
from . import views

urlpatterns = [
    path("", views.SaleListCreateView.as_view()),
    path("next-number/", views.SaleNextNumberView.as_view()),
    path("<int:pk>/", views.SaleDetailView.as_view()),
    path("returns/", views.SaleReturnListCreateView.as_view()),
    path("quotations/", views.QuotationListCreateView.as_view()),
    path("quotations/<int:pk>/", views.QuotationDetailView.as_view()),
]
