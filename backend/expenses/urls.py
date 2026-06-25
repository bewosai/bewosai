from django.urls import path
from . import views

urlpatterns = [
    path("categories/", views.ExpenseCategoryListCreateView.as_view()),
    path("", views.ExpenseListCreateView.as_view()),
    path("<int:pk>/", views.ExpenseDetailView.as_view()),
]
