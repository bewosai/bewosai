from django.urls import path
from . import views

urlpatterns = [
    path("", views.BusinessStaffListView.as_view()),
    path("invite/", views.BusinessStaffInviteView.as_view()),
    path("activity/", views.BusinessStaffActivityView.as_view()),
    path("audit-log/", views.StaffAuditLogView.as_view()),
]
