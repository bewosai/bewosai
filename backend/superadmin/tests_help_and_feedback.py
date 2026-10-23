"""
The help chat answers how-to questions about Bewosai only, and every question
reaches Super Admin; a feedback message can't be posted pre-"answered".
"""
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import Business, StaffMember, User
from superadmin.help_guide import answer
from superadmin.models import HelpQuestion, SupportTicket


class HelpGuideTests(TestCase):
    def test_how_to_questions_get_the_right_topic(self):
        cases = {
            "How do I make a new invoice?": "New sale / invoice",
            "how to add expense for rent": "Expense",
            "where is balance sheet": "Balance sheet",
            "kasari customer add garne": "Customers & suppliers",
            "I didn't get the login code": "Sign in",
            "how to return goods to supplier": "Returns",
            "can I delete my account": "Delete account",
            "sort list a to z": "Sorting & search",
            "apply coupon code": "Plan / coupon",
        }
        for question, topic in cases.items():
            self.assertEqual(answer(question)[1], topic, question)

    def test_every_topic_answers_in_numbered_steps(self):
        from superadmin.help_guide import GUIDE, STEPS

        self.assertEqual({g["topic"] for g in GUIDE}, set(STEPS))
        for entry in GUIDE:
            self.assertIn("\n1. ", entry["answer"], entry["topic"])
            self.assertIn("\n2. ", entry["answer"], entry["topic"])

    def test_off_topic_questions_are_declined(self):
        for question in ("what is the capital of france", "write me a poem", "", "   ", "who won the football match",
                         "tell me a joke", "what is the weather today"):
            text, topic, _ = answer(question)
            self.assertIsNone(topic, question)
            self.assertIn("only help with how to use Bewosai", text)


@override_settings(SUPERADMIN_EMAIL="admin@example.com")
class HelpAndFeedbackApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="ram@example.com", name="Ram")
        self.business = Business.objects.create(owner=self.user, name="Ram Shop")
        StaffMember.objects.create(user=self.user, business=self.business, role=StaffMember.ROLE_OWNER)
        self.api = APIClient(HTTP_X_BUSINESS_ID=str(self.business.id))
        self.api.force_authenticate(self.user)

    def test_question_is_answered_and_saved_for_super_admin(self):
        res = self.api.post("/api/superadmin/help/ask/", {"question": "How do I add a product?"}, format="json")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertEqual(res.data["topic"], "Add item / product")
        q = HelpQuestion.objects.get()
        self.assertEqual((q.user_email, q.business_name, q.topic), ("ram@example.com", "Ram Shop", "Add item / product"))
        self.assertEqual(self.api.post("/api/superadmin/help/ask/", {"question": ""}, format="json").status_code, 400)

    def test_only_super_admin_lists_questions(self):
        self.api.post("/api/superadmin/help/ask/", {"question": "weather today?"}, format="json")
        self.assertEqual(self.api.get("/api/superadmin/help/questions/").status_code, 403)

    def test_feedback_cannot_be_sent_already_answered(self):
        res = self.api.post("/api/superadmin/support/", {
            "subject": "Idea", "message": "Please add X", "status": "CLOSED", "admin_reply": "Done!",
            "user_email": "someone@else.com", "business_name": "Fake",
        }, format="json")
        self.assertEqual(res.status_code, 201, res.content)
        ticket = SupportTicket.objects.get()
        self.assertEqual((ticket.status, ticket.admin_reply, ticket.user_email, ticket.business_name),
                         ("OPEN", "", "ram@example.com", "Ram Shop"))
        mine = self.api.get("/api/superadmin/my-tickets/").data
        mine = mine["results"] if isinstance(mine, dict) else mine
        self.assertEqual(len(mine), 1)
