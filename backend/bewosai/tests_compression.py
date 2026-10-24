"""API responses are gzip-compressed for clients that accept it; sign-in
responses (tokens) are not."""
import gzip
import json

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product


class CompressionTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=business, role=StaffMember.ROLE_OWNER)
        for i in range(60):
            Product.objects.create(business=business, name=f"Product number {i}", sale_price=100)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        self.api.force_authenticate(owner)

    def test_lists_are_compressed_and_still_read_back_the_same(self):
        res = self.api.get("/api/inventory/products/", HTTP_ACCEPT_ENCODING="gzip")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Encoding"], "gzip")
        body = json.loads(gzip.decompress(res.content))
        plain = self.api.get("/api/inventory/products/")
        self.assertNotIn("Content-Encoding", plain)
        self.assertEqual(body, json.loads(plain.content))
        self.assertLess(len(res.content), len(plain.content) / 3)

    def test_sign_in_responses_are_not_compressed(self):
        res = APIClient().post("/api/auth/send-otp/", {"identifier": ""}, format="json", HTTP_ACCEPT_ENCODING="gzip")
        self.assertNotIn("Content-Encoding", res)
