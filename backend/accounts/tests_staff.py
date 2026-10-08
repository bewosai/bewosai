from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import ACCOUNT_BUSINESS, Business, OTPCode, StaffInvitation, StaffMember, User
from accounts.staff_test_utils import accept_invite, signed_in_client


class StaffFlowTests(TestCase):
    """Invite -> share link -> person proves their email with a code -> accepts
    -> gets exactly the access granted. Plus limits, resend/cancel, removal."""

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
        self.invites_url = f"{self.url}invitations/"

    def invite(self, name="Sita", role="CASHIER", client=None, permissions=None, email=""):
        return (client or self.api).post(
            self.url, {"name": name, "role": role, "permissions": permissions or {}, "email": email}, format="json",
        )

    def join(self, name="Sita", role="CASHIER", permissions=None, email=None):
        """Invite and accept. Returns (staff client, accept response)."""
        res = self.invite(name, role, permissions=permissions)
        self.assertEqual(res.status_code, 201, res.content)
        accepted = accept_invite(res.data["token"], email or f"{name.lower().replace(' ', '')}@example.com")
        self.assertEqual(accepted.status_code, 200, accepted.content)
        return signed_in_client(accepted.data["access"], self.business.id), accepted

    # ── invitation: nothing is granted until the person accepts ──────────
    def test_invite_creates_a_pending_invitation_not_a_member(self):
        res = self.invite("Sita", "SALESPERSON")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertTrue(res.data["token"])
        self.assertEqual((res.data["status"], res.data["role_label"]), ("PENDING", "Salesperson"))
        self.assertFalse(StaffMember.objects.filter(business=self.business).exclude(role="OWNER").exists())
        # the secret is never stored as-is
        inv = StaffInvitation.objects.get()
        self.assertNotEqual(inv.token_hash, res.data["token"])
        listed = self.api.get(self.invites_url).data
        rows = listed["results"] if isinstance(listed, dict) else listed
        self.assertEqual([r["name"] for r in rows], ["Sita"])
        self.assertNotIn("token", rows[0])

    def test_the_link_shows_the_business_role_and_access_without_signing_in(self):
        perms = {"sales": {"view": True, "create": True, "edit": False, "delete": False},
                 "purchases": {"view": False, "create": False, "edit": False, "delete": False}}
        token = self.invite("Sita", "SALESPERSON", permissions=perms).data["token"]
        res = APIClient().get(f"/api/auth/staff-invite/{token}/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(res.data["business_name"], "Shop")
        self.assertEqual(res.data["role_label"], "Salesperson")
        self.assertEqual(res.data["access"]["sales"], {"view": True, "create": True, "edit": False, "delete": False})
        self.assertFalse(res.data["access"]["purchases"]["view"])
        self.assertFalse(res.data["access"]["staff"]["view"])  # never implied

    def test_accepting_needs_the_right_email_code(self):
        token = self.invite("Sita").data["token"]
        OTPCode.generate("sita@example.com", ACCOUNT_BUSINESS)
        wrong = accept_invite(token, "sita@example.com", code="000000")
        self.assertEqual(wrong.status_code, 400)
        self.assertFalse(StaffMember.objects.filter(user__email="sita@example.com").exists())
        # no code was ever sent to this address
        self.assertEqual(accept_invite(token, "other@example.com", code="123456").status_code, 400)

    def test_accepting_joins_the_business_and_signs_in(self):
        client, res = self.join("Sita", "CASHIER")
        self.assertEqual(res.data["business_id"], self.business.id)
        self.assertEqual([b["id"] for b in res.data["businesses"]], [self.business.id])
        member = StaffMember.objects.get(user__email="sita@example.com")
        self.assertEqual((member.role, member.is_active, member.business_id), ("CASHIER", True, self.business.id))
        self.assertIsNone(member.login_token)
        self.assertEqual(client.get("/api/sales/").status_code, 200)
        self.assertEqual(StaffInvitation.objects.get().status, "ACCEPTED")

    def test_a_link_works_only_once(self):
        token = self.invite("Sita").data["token"]
        self.assertEqual(accept_invite(token, "sita@example.com").status_code, 200)
        again = accept_invite(token, "someone.else@example.com")
        self.assertEqual(again.status_code, 410)
        self.assertFalse(User.objects.filter(email="someone.else@example.com").exists())

    def test_an_invitation_locked_to_an_email_refuses_any_other(self):
        token = self.invite("Sita", email="sita@example.com").data["token"]
        self.assertEqual(accept_invite(token, "intruder@example.com").status_code, 403)
        self.assertEqual(accept_invite(token, "sita@example.com").status_code, 200)

    def test_expired_declined_and_cancelled_links_do_nothing(self):
        expired = self.invite("A").data
        StaffInvitation.objects.filter(pk=expired["id"]).update(expires_at=timezone.now() - timedelta(minutes=1))
        self.assertEqual(accept_invite(expired["token"], "a@example.com").status_code, 410)
        self.assertEqual(APIClient().get(f"/api/auth/staff-invite/{expired['token']}/").status_code, 410)

        declined = self.invite("B").data
        self.assertEqual(APIClient().post(f"/api/auth/staff-invite/{declined['token']}/decline/").status_code, 200)
        self.assertEqual(accept_invite(declined["token"], "b@example.com").status_code, 410)

        cancelled = self.invite("C").data
        self.assertEqual(self.api.delete(f"{self.invites_url}{cancelled['id']}/").status_code, 204)
        self.assertEqual(accept_invite(cancelled["token"], "c@example.com").status_code, 410)
        self.assertFalse(StaffMember.objects.filter(business=self.business).exclude(role="OWNER").exists())

    def test_a_made_up_link_is_rejected(self):
        self.assertEqual(APIClient().get("/api/auth/staff-invite/not-a-real-token/").status_code, 404)
        self.assertEqual(accept_invite("not-a-real-token", "x@example.com").status_code, 404)

    def test_resending_gives_a_new_link_and_kills_the_old_one(self):
        created = self.invite("Sita").data
        res = self.api.post(f"{self.invites_url}{created['id']}/resend/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertNotEqual(res.data["token"], created["token"])
        self.assertEqual(accept_invite(created["token"], "sita@example.com").status_code, 404)
        self.assertEqual(accept_invite(res.data["token"], "sita@example.com").status_code, 200)

    def test_the_owner_cannot_accept_their_own_business_invite(self):
        token = self.invite("Me").data["token"]
        self.assertEqual(accept_invite(token, "owner@example.com").status_code, 400)

    def test_old_direct_add_endpoint_now_only_sends_an_invitation(self):
        existing = User.objects.create_user(email="victim@example.com", name="Victim")
        res = self.api.post("/api/staff/invite/", {"email": "victim@example.com", "role": "MANAGER"}, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertFalse(StaffMember.objects.filter(user=existing).exists())   # no consent, no access
        self.assertEqual(StaffInvitation.objects.get().email, "victim@example.com")

    # ── role permissions actually apply to the signed-in staff ───────────
    def test_cashier_can_use_sales_but_not_purchases(self):
        perms = {
            "sales": {"view": True, "create": True, "edit": False, "delete": False},
            "purchases": {"view": False, "create": False, "edit": False, "delete": False},
        }
        client, _ = self.join("C", "CASHIER", permissions=perms)
        self.assertEqual(client.get("/api/sales/").status_code, 200)
        self.assertEqual(client.get("/api/purchases/").status_code, 403)

    def test_staff_without_the_staff_module_cannot_manage_staff(self):
        client, _ = self.join("C", "CASHIER")
        self.assertEqual(client.get(self.url).status_code, 403)
        self.assertEqual(self.invite("X", "CASHIER", client=client).status_code, 403)
        self.assertEqual(client.get(self.invites_url).status_code, 403)

    def test_a_manager_cannot_grant_more_than_they_have(self):
        perms = {"staff": {"view": True, "create": True, "edit": True, "delete": False},
                 "banking": {"view": False, "create": False, "edit": False, "delete": False}}
        manager, _ = self.join("Mgr", "MANAGER", permissions=perms)
        full_banking = {"banking": {"view": True, "create": True, "edit": True, "delete": True}}
        self.business.staff_limit_override = 5
        self.business.save()
        self.assertEqual(self.invite("X", client=manager, permissions=full_banking).status_code, 403)
        member = StaffMember.objects.get(user__email="mgr@example.com")
        res = manager.patch(f"{self.url}{member.id}/", {"permissions": {**perms, **full_banking}}, format="json")
        self.assertEqual(res.status_code, 403)

    # ── several staff + plan limit ───────────────────────────────────────
    def test_free_plan_cannot_manage_staff_at_all(self):
        self.business.plan = Business.PLAN_FREE
        self.business.save()
        res = self.invite("One")
        self.assertEqual(res.status_code, 403)
        self.assertIn("staff_management", res.data["detail"])

    def test_the_website_allows_five_staff_then_a_clear_error(self):
        for n in range(5):
            self.assertEqual(self.invite(f"Staff {n}").status_code, 201, n)
        over = self.invite("Sixth")
        self.assertEqual(over.status_code, 403)
        self.assertIn("up to 5 staff", over.data["error"])

    def test_the_app_allows_three_staff_then_says_the_website_allows_more(self):
        app = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id), HTTP_X_PLATFORM="mobile")
        app.force_authenticate(self.owner)
        for n in range(3):
            self.assertEqual(self.invite(f"Staff {n}", client=app).status_code, 201, n)
        over = self.invite("Fourth", client=app)
        self.assertEqual(over.status_code, 403)
        self.assertIn("up to 3 staff", over.data["error"])
        self.assertIn("5 on the website", over.data["error"])
        # the website can still add up to 5
        self.assertEqual(self.invite("Fourth").status_code, 201)

    def test_the_plan_does_not_change_the_staff_limit(self):
        self.business.plan = Business.PLAN_PREMIUMPLUS
        self.business.save()
        for n in range(5):
            self.assertEqual(self.invite(f"Staff {n}").status_code, 201, n)
        self.assertEqual(self.invite("Sixth").status_code, 403)

    def test_pending_and_accepted_both_count_toward_the_limit(self):
        self.business.staff_limit_override = 2
        self.business.save()
        self.join("A")
        self.assertEqual(self.invite("B").status_code, 201)       # pending
        self.assertEqual(self.invite("C").status_code, 403)
        # cancelling the pending one frees its slot
        pending = StaffInvitation.objects.get(name="B")
        self.api.delete(f"{self.invites_url}{pending.id}/")
        self.assertEqual(self.invite("C").status_code, 201)

    def test_an_expired_invite_frees_its_slot(self):
        self.business.staff_limit_override = 1
        self.business.save()
        first = self.invite("A").data
        StaffInvitation.objects.filter(pk=first["id"]).update(expires_at=timezone.now() - timedelta(minutes=1))
        self.assertEqual(self.invite("B").status_code, 201)
        # and resending the expired one now needs a slot that isn't there
        self.assertEqual(self.api.post(f"{self.invites_url}{first['id']}/resend/").status_code, 403)

    # ── revoke / remove ──────────────────────────────────────────────────
    def test_deactivated_staff_lose_access(self):
        client, _ = self.join("Sita", permissions={"sales": {"view": True}})
        member = StaffMember.objects.get(user__email="sita@example.com")
        from datetime import date
        from sales.models import Sale
        Sale.objects.create(business=self.business, invoice_number="S1", sale_date=date.today())
        self.assertEqual(client.get("/api/sales/").json()["count"], 1)
        self.api.patch(f"{self.url}{member.id}/", {"is_active": False}, format="json")
        res = client.get("/api/sales/")
        # Either refused outright or shown nothing - never the business's data.
        self.assertTrue(res.status_code in (403, 404) or res.json()["count"] == 0, res.content)
        businesses = client.get("/api/auth/businesses/").json()
        self.assertEqual(businesses["count"] if isinstance(businesses, dict) else len(businesses), 0)

    def test_removed_staff_frees_a_slot_and_can_be_invited_back(self):
        self.business.staff_limit_override = 1
        self.business.save()
        self.join("Sita")
        member = StaffMember.objects.get(user__email="sita@example.com")
        self.assertEqual(self.api.delete(f"{self.url}{member.id}/").status_code, 204)
        self.join("Sita", role="VIEWER")
        self.assertEqual(StaffMember.objects.get(user__email="sita@example.com").role, "VIEWER")

    def test_email_staff_get_no_bearer_login_link(self):
        self.join("Sita")
        member = StaffMember.objects.get(user__email="sita@example.com")
        self.assertEqual(self.api.post(f"{self.url}{member.id}/regenerate-link/").status_code, 400)

    def test_existing_login_link_staff_keep_working(self):
        legacy = User.objects.create_user(name="Old", account_type=ACCOUNT_BUSINESS, is_verified=True, allow_no_identity=True)
        member = StaffMember.objects.create(user=legacy, business=self.business, role="CASHIER",
                                            login_token=StaffMember.new_login_token())
        res = APIClient().post("/api/auth/staff-login/", {"token": member.login_token}, format="json")
        self.assertEqual(res.status_code, 200, res.content)

    def test_changing_a_role_works_and_owner_role_cannot_be_granted(self):
        self.join("Sita", "CASHIER")
        member = StaffMember.objects.get(user__email="sita@example.com")
        ok = self.api.patch(f"{self.url}{member.id}/", {"role": "ACCOUNTANT"}, format="json")
        self.assertEqual((ok.status_code, ok.data["role"]), (200, "ACCOUNTANT"))
        bad = self.api.patch(f"{self.url}{member.id}/", {"role": "OWNER"}, format="json")
        self.assertEqual(bad.status_code, 400)
        self.assertEqual(self.invite("X", role="OWNER").status_code, 400)

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
        client, _ = self.join("Mgr", "MANAGER", permissions=perms)
        owner_row = StaffMember.objects.get(business=self.business, role="OWNER")
        res = client.delete(f"{self.url}{owner_row.id}/")
        self.assertIn(res.status_code, (400, 403))
        self.assertTrue(StaffMember.objects.filter(pk=owner_row.pk).exists())

    def test_reactivating_a_staff_member_still_respects_the_limit(self):
        self.business.staff_limit_override = 1
        self.business.save()
        self.join("First")
        first = StaffMember.objects.get(user__email="first@example.com")
        self.api.patch(f"{self.url}{first.id}/", {"is_active": False}, format="json")
        self.assertEqual(self.invite("Second").status_code, 201)     # takes the freed slot
        again = self.api.patch(f"{self.url}{first.id}/", {"is_active": True}, format="json")
        self.assertEqual(again.status_code, 403)
        first.refresh_from_db()
        self.assertFalse(first.is_active)

    def test_another_business_owner_cannot_touch_this_staff_list(self):
        stranger = User.objects.create_user(email="other@example.com", name="Other")
        other_biz = Business.objects.create(owner=stranger, name="Other Shop")
        StaffMember.objects.create(user=stranger, business=other_biz, role="OWNER")
        client = APIClient()
        client.force_authenticate(stranger)
        self.assertIn(self.invite("Hacker", client=client).status_code, (403, 404))
        self.assertFalse(StaffInvitation.objects.filter(business=self.business).exists())
        mine = self.invite("Sita").data
        self.assertIn(client.post(f"{self.invites_url}{mine['id']}/resend/").status_code, (403, 404))
        self.assertIn(client.delete(f"{self.invites_url}{mine['id']}/").status_code, (403, 404))
