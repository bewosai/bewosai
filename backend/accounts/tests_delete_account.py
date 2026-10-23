"""
Deleting your own account (Google Play requires it for apps with sign-up):
only with a fresh emailed code, and it takes the businesses you own with it —
never a business you're only staff in.
"""
from unittest import mock

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import Business, OTPCode, StaffMember, User
from sales.models import Sale


class DeleteAccountTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="ram@example.com", name="Ram")
        self.shop = Business.objects.create(owner=self.user, name="Ram Shop")
        StaffMember.objects.create(user=self.user, business=self.shop, role=StaffMember.ROLE_OWNER)
        Sale.objects.create(business=self.shop, invoice_number="INV-1", sale_date="2026-10-01", subtotal=100)

        boss = User.objects.create_user(email="boss@example.com", name="Boss")
        self.other = Business.objects.create(owner=boss, name="Boss Shop")
        StaffMember.objects.create(user=boss, business=self.other, role=StaffMember.ROLE_OWNER)
        StaffMember.objects.create(user=self.user, business=self.other, role=StaffMember.ROLE_CASHIER)

        self.api = APIClient()
        self.api.force_authenticate(self.user)

    def code(self):
        _, code = OTPCode.generate(self.user.email, self.user.account_type)
        return code

    def test_right_code_deletes_the_account_and_what_it_owns(self):
        res = self.api.post("/api/auth/delete-account/", {"code": self.code()}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertFalse(User.objects.filter(email="ram@example.com").exists())
        self.assertFalse(Business.objects.filter(pk=self.shop.pk).exists())
        self.assertFalse(Sale.objects.filter(invoice_number="INV-1").exists())
        # A business they only worked in stays, minus them.
        self.assertTrue(Business.objects.filter(pk=self.other.pk).exists())
        self.assertEqual(self.other.staff.count(), 1)

    def test_super_admin_delete_of_a_business_with_records_works(self):
        # The same cascade through the admin endpoints used to fail on the
        # activity log rows it wrote mid-delete.
        self.shop.delete()
        self.assertFalse(Sale.objects.filter(invoice_number="INV-1").exists())

    def test_deleting_one_sale_is_still_logged(self):
        from superadmin.models import ActivityLog
        sale = Sale.objects.get(invoice_number="INV-1")
        sale.delete()
        self.assertTrue(ActivityLog.objects.filter(business=self.shop, action="DELETED", model_name="Sale").exists())

    def test_wrong_or_missing_code_deletes_nothing(self):
        self.code()
        for payload in ({"code": "000000"}, {}):
            res = self.api.post("/api/auth/delete-account/", payload, format="json")
            self.assertEqual(res.status_code, 400)
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_needs_to_be_signed_in(self):
        self.assertEqual(APIClient().post("/api/auth/delete-account/", {"code": "1"}).status_code, 401)

    def test_super_admin_cannot_delete_itself_here(self):
        with override_settings(SUPERADMIN_EMAIL="ram@example.com"):
            res = self.api.post("/api/auth/delete-account/", {"code": self.code()}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_the_code_comes_from_the_normal_send_otp(self):
        with mock.patch("accounts.views.send_otp_email", return_value=True) as sent:
            res = APIClient().post("/api/auth/send-otp/", {"identifier": "ram@example.com"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        code = sent.call_args[0][1]
        res = self.api.post("/api/auth/delete-account/", {"code": code}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
