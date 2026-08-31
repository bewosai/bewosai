from django.test import TestCase

from accounts.models import User, Business
from superadmin.models import ActivityLog
from parties.models import Party
from expenses.models import Expense


class ActivityLogSignalTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="owner@example.com", name="Owner")
        self.business = Business.objects.create(owner=self.user, name="Test Biz")

    def test_create_logs_activity_with_business_only_model(self):
        party = Party.objects.create(business=self.business, name="Ram")
        log = ActivityLog.objects.get(model_name="Party", object_repr__contains="Ram")
        self.assertEqual(log.action, ActivityLog.ACTION_CREATED)
        self.assertEqual(log.business, self.business)
        self.assertIsNone(log.user)
        party.delete()
        log2 = ActivityLog.objects.get(model_name="Party", action=ActivityLog.ACTION_DELETED)
        self.assertEqual(log2.business, self.business)

    def test_create_logs_activity_with_created_by(self):
        Expense.objects.create(
            business=self.business, amount=100, date="2026-01-01", created_by=self.user,
        )
        log = ActivityLog.objects.get(model_name="Expense")
        self.assertEqual(log.action, ActivityLog.ACTION_CREATED)
        self.assertEqual(log.user, self.user)
        self.assertIn("100", log.object_repr)

    def test_update_does_not_log(self):
        party = Party.objects.create(business=self.business, name="Shyam")
        count_before = ActivityLog.objects.count()
        party.name = "Shyam Updated"
        party.save()
        self.assertEqual(ActivityLog.objects.count(), count_before)
