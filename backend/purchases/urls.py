from django.urls import path
from . import views

urlpatterns = [
    path("", views.PurchaseListCreateView.as_view(), name="purchase-list"),
    path("<int:pk>/", views.PurchaseDetailView.as_view(), name="purchase-detail"),
    path("returns/", views.PurchaseReturnListCreateView.as_view(), name="purchase-return-list"),
    path("recycle-bin/", views.RecycleBinView.as_view(), name="recycle-bin"),
    path("recycle-bin/restore/<str:record_type>/<int:pk>/", views.RecycleBinRestoreView.as_view(), name="recycle-restore"),
    path("recycle-bin/delete/<str:record_type>/<int:pk>/", views.RecycleBinPermanentDeleteView.as_view(), name="recycle-delete"),
]
