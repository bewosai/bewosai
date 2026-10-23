"""Choosing Product or Service when adding an item is saved, returned and
filterable — it used to be silently dropped, so every item became a Product."""
from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from inventory.models import Product


class ItemTypeTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@example.com", name="O")
        business = Business.objects.create(owner=owner, name="Shop")
        StaffMember.objects.create(user=owner, business=business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(business.id))
        self.api.force_authenticate(owner)

    def add(self, **data):
        res = self.api.post("/api/inventory/products/", {"sale_price": "500", **data}, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        return res.data

    def test_service_is_saved_and_never_stocked(self):
        item = self.add(name="Repair", item_type="SERVICE", stock_quantity="9")
        self.assertEqual(item["item_type"], "SERVICE")
        self.assertEqual(Product.objects.get(pk=item["id"]).stock_quantity, 0)

    def test_default_is_product_and_list_filters_by_type(self):
        self.assertEqual(self.add(name="Rice")["item_type"], "PRODUCT")
        self.add(name="Repair", item_type="SERVICE")
        rows = self.api.get("/api/inventory/products/", {"item_type": "SERVICE"}).data
        rows = rows["results"] if isinstance(rows, dict) else rows
        self.assertEqual([r["name"] for r in rows], ["Repair"])
