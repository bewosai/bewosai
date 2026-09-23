from rest_framework.test import APIClient
from django.test import TestCase

from accounts.models import Business, StaffMember, User


class StaffFlowTests(TestCase):
    """Invite -> share link -> staff signs in -> role limits -> revoke/remove."""

    def setUp(self):
        self.owner = User.objects.create_user(email="owner@example.com", name="Owner")
        # Staff management is a Premium-only feature (see the seeded
        # "staff_management" Feature), so the business under test is Premium.
        self.business = Business.objects.create(owner=self.owner, name="Shop", plan=Business.PLAN_PREMIUM)
        StaffMember.objects.create(user=self.owner, business=self.business, role=StaffMember.ROLE_OWNER)
        # Both apps send the current business on every request; the Premium-only
        # feature check resolves the business from this header.
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.owner)
        self.url = f"/api/auth/businesses/{self.business.id}/staff/"

    def invite(self, name="Sita", role="CASHIER", client=None):
        return (client or self.api).post(self.url, {"name": name, "role": role, "permissions": {}}, format="json")

    def staff_client(self, token):
        res = APIClient().post("/api/auth/staff-login/", {"token": token}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        client = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        return client, res

    def as_staff(self, client, path):
        return client.get(path, HTTP_X_BUSINESS_ID=str(self.business.id))

    # ── invite + sign in ─────────────────────────────────────────────────
    def test_invite_creates_a_link_only_member(self):
        res = self.invite("Sita", "CASHIER")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertTrue(res.data["login_token"])
        self.assertEqual(res.data["role"], "CASHIER")
        self.assertEqual(res.data["user_name"], "Sita")

    def test_staff_signs_in_with_the_link_and_sees_the_business(self):
        token = self.invite("Sita", "CASHIER").data["login_token"]
        _, res = self.staff_client(token)
        self.assertEqual([b["id"] for b in res.data["businesses"]], [self.business.id])

    def test_a_wrong_or_missing_link_is_rejected(self):
        self.assertEqual(APIClient().post("/api/auth/staff-login/", {"token": "nope"}, format="json").status_code, 404)
        self.assertEqual(APIClient().post("/api/auth/staff-login/", {}, format="json").status_code, 400)

    # ── role permissions actually apply to the signed-in staff ───────────
    def test_cashier_can_use_sales_but_not_purchases(self):
        perms = {
            "sales": {"view": True, "create": True, "edit": False, "delete": False},
            "purchases": {"view": False, "create": False, "edit": False, "delete": False},
        }
        res = self.api.post(self.url, {"name": "C", "role": "CASHIER", "permissions": perms}, format="json")
        client, _ = self.staff_client(res.data["login_token"])
        self.assertEqual(self.as_staff(client, "/api/sales/").status_code, 200)
        self.assertEqual(self.as_staff(client, "/api/purchases/").status_code, 403)

    def test_staff_without_the_staff_module_cannot_manage_staff(self):
        token = self.invite("C", "CASHIER").data["login_token"]
        client, _ = self.staff_client(token)
        # Staff with no "staff" module access can neither list, invite nor remove.
        self.assertEqual(client.get(self.url).status_code, 403)
        self.assertEqual(self.invite("X", "CASHIER", client=client).status_code, 403)

    # ── several staff + plan limit ───────────────────────────────────────
    def test_free_plan_cannot_manage_staff_at_all(self):
        # "1 User Account" on the Free plan: the feature itself is Premium-only.
        self.business.plan = Business.PLAN_FREE
        self.business.save()
        res = self.invite("One")
        self.assertEqual(res.status_code, 403)
        self.assertIn("staff_management", res.data["detail"])

    def test_premium_allows_up_to_three_staff_then_a_clear_error(self):
        for n in range(3):
            self.assertEqual(self.invite(f"Staff {n}").status_code, 201, n)
        over = self.invite("Fourth")
        self.assertEqual(over.status_code, 403)
        self.assertIn("up to 3", over.data["error"])
        self.assertIn("Premium plan", over.data["error"])

    def test_premium_plus_allows_up_to_five_staff_then_a_clear_error(self):
        self.business.plan = Business.PLAN_PREMIUMPLUS
        self.business.save()
        for n in range(5):
            self.assertEqual(self.invite(f"Staff {n}").status_code, 201, n)
        over = self.invite("Sixth")
        self.assertEqual(over.status_code, 403)
        self.assertIn("up to 5", over.data["error"])
        self.assertIn("Premium Plus plan", over.data["error"])

    def test_several_staff_up_to_the_limit_then_a_clear_error(self):
        self.business.staff_limit_override = 3
        self.business.save()
        for n in range(3):
            self.assertEqual(self.invite(f"Staff {n}").status_code, 201)
        over = self.invite("Too many")
        self.assertEqual(over.status_code, 403)
        self.assertIn("up to 3", over.data["error"])
        self.assertEqual(StaffMember.objects.filter(business=self.business).exclude(role="OWNER").count(), 3)

    def test_each_staff_member_gets_their_own_link(self):
        self.business.staff_limit_override = 2
        self.business.save()
        a = self.invite("A").data["login_token"]
        b = self.invite("B").data["login_token"]
        self.assertNotEqual(a, b)

    # ── revoke / remove ──────────────────────────────────────────────────
    def test_regenerating_the_link_kills_the_old_one(self):
        created = self.invite("Sita").data
        old = created["login_token"]
        res = self.api.post(f"{self.url}{created['id']}/regenerate-link/")
        self.assertEqual(res.status_code, 200)
        new = res.data["login_token"]
        self.assertNotEqual(old, new)
        self.assertEqual(APIClient().post("/api/auth/staff-login/", {"token": old}, format="json").status_code, 404)
        self.staff_client(new)

    def test_deactivated_staff_cannot_sign_in(self):
        created = self.invite("Sita").data
        self.api.patch(f"{self.url}{created['id']}/", {"is_active": False}, format="json")
        res = APIClient().post("/api/auth/staff-login/", {"token": created["login_token"]}, format="json")
        self.assertEqual(res.status_code, 404)

    def test_removed_staff_cannot_sign_in_and_frees_a_slot(self):
        created = self.invite("Sita").data
        self.assertEqual(self.api.delete(f"{self.url}{created['id']}/").status_code, 204)
        res = APIClient().post("/api/auth/staff-login/", {"token": created["login_token"]}, format="json")
        self.assertEqual(res.status_code, 404)
        self.assertEqual(self.invite("Replacement").status_code, 201)

    def test_changing_a_role_works_and_owner_role_cannot_be_granted(self):
        created = self.invite("Sita", "CASHIER").data
        ok = self.api.patch(f"{self.url}{created['id']}/", {"role": "MANAGER"}, format="json")
        self.assertEqual((ok.status_code, ok.data["role"]), (200, "MANAGER"))
        bad = self.api.patch(f"{self.url}{created['id']}/", {"role": "OWNER"}, format="json")
        self.assertEqual(bad.status_code, 400)

    # ── the owner can't be removed or downgraded through the staff list ──
    def test_the_owners_own_membership_cannot_be_deleted_or_deactivated(self):
        owner_row = StaffMember.objects.get(business=self.business, role="OWNER")
        self.assertEqual(self.api.delete(f"{self.url}{owner_row.id}/").status_code, 400)
        self.assertEqual(self.api.patch(f"{self.url}{owner_row.id}/", {"is_active": False}, format="json").status_code, 400)
        self.assertEqual(self.api.patch(f"{self.url}{owner_row.id}/", {"role": "VIEWER"}, format="json").status_code, 400)
        owner_row.refresh_from_db()
        self.assertTrue(owner_row.is_active)
        self.assertEqual(owner_row.role, "OWNER")

    def test_a_manager_with_staff_access_cannot_remove_the_owner(self):
        perms = {"staff": {"view": True, "create": True, "edit": True, "delete": True}}
        token = self.api.post(self.url, {"name": "Mgr", "role": "MANAGER", "permissions": perms}, format="json").data["login_token"]
        client, _ = self.staff_client(token)
        owner_row = StaffMember.objects.get(business=self.business, role="OWNER")
        res = client.delete(f"{self.url}{owner_row.id}/", HTTP_X_BUSINESS_ID=str(self.business.id))
        self.assertIn(res.status_code, (400, 403))
        self.assertTrue(StaffMember.objects.filter(pk=owner_row.pk).exists())

    def test_reactivating_a_staff_member_still_respects_the_limit(self):
        self.business.staff_limit_override = 1
        self.business.save()
        first = self.invite("First").data
        self.api.patch(f"{self.url}{first['id']}/", {"is_active": False}, format="json")
        self.assertEqual(self.invite("Second").status_code, 201)     # takes the freed slot
        again = self.api.patch(f"{self.url}{first['id']}/", {"is_active": True}, format="json")
        self.assertEqual(again.status_code, 403)
        self.assertFalse(StaffMember.objects.get(pk=first["id"]).is_active)

    def test_another_business_owner_cannot_touch_this_staff_list(self):
        stranger = User.objects.create_user(email="other@example.com", name="Other")
        other_biz = Business.objects.create(owner=stranger, name="Other Shop")
        StaffMember.objects.create(user=stranger, business=other_biz, role="OWNER")
        client = APIClient()
        client.force_authenticate(stranger)
        self.assertIn(self.invite("Hacker", client=client).status_code, (403, 404))
        self.assertFalse(StaffMember.objects.filter(business=self.business, user__name="Hacker").exists())
