from django.urls import path
from . import views

urlpatterns = [
    path("dashboard/", views.DashboardSummaryView.as_view()),
    path("sales/", views.SalesReportView.as_view()),
    path("expenses/", views.ExpenseReportView.as_view()),
    path("inventory/", views.InventoryReportView.as_view()),
    path("profit/", views.ProfitReportView.as_view()),
]
