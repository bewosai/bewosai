from django.urls import path
from . import views

urlpatterns = [
    path("dashboard/", views.DashboardSummaryView.as_view()),
    path("sales/", views.SalesReportView.as_view()),
    path("expenses/", views.ExpenseReportView.as_view()),
    path("inventory/", views.InventoryReportView.as_view()),
    path("profit/", views.ProfitReportView.as_view()),
    path("monthly/", views.MonthlyReportView.as_view()),
    path("receivable-aging/", views.ReceivableAgingView.as_view()),
    path("day-book/", views.DayBookView.as_view()),
    path("cash-flow/", views.CashFlowView.as_view()),
    path("stock/", views.StockReportView.as_view()),
    path("cash-in-hand/", views.CashInHandView.as_view()),
    path("bank-statement/", views.BankStatementView.as_view()),
    path("all-transactions/", views.AllTransactionsView.as_view()),
]
