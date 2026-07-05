from django.urls import path
from . import views

urlpatterns = [
    path("categories/", views.CategoryListCreateView.as_view()),
    path("categories/<int:pk>/", views.CategoryDetailView.as_view()),
    path("units/", views.UnitListCreateView.as_view()),
    path("units/<int:pk>/", views.UnitDetailView.as_view()),
    path("products/", views.ProductListCreateView.as_view()),
    path("products/<int:pk>/", views.ProductDetailView.as_view()),
    path("products/bulk-import/", views.ProductBulkImportView.as_view()),
    path("stock-movements/", views.StockMovementListCreateView.as_view()),
]
