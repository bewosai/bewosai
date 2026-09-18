"""
Gives an account platform-admin (Super Admin) rights, creating the account if
it doesn't exist yet:

    python manage.py make_platform_admin someone@example.com

They then sign in normally (emailed code or Google) and the Super Admin panel
appears. To do the same without a shell, set PLATFORM_ADMIN_EMAILS instead.
"""
from django.core.management.base import BaseCommand, CommandError

from accounts.models import ACCOUNT_BUSINESS, User


class Command(BaseCommand):
    help = "Grant platform-admin (Super Admin) rights to an email, creating the account if needed."

    def add_arguments(self, parser):
        parser.add_argument("email")
        parser.add_argument("--revoke", action="store_true", help="Remove admin rights instead.")

    def handle(self, *args, email, revoke=False, **options):
        email = email.strip().lower()
        if "@" not in email:
            raise CommandError(f"'{email}' doesn't look like an email address.")
        user = User.objects.filter(email=email).first()
        if revoke:
            if not user:
                raise CommandError(f"No account with email {email}.")
            user.is_platform_admin = False
            user.save(update_fields=["is_platform_admin"])
            self.stdout.write(self.style.SUCCESS(f"{email} is no longer a platform admin."))
            return
        created = user is None
        if created:
            user = User.objects.create_user(
                email=email, name=email.split("@")[0].capitalize(), account_type=ACCOUNT_BUSINESS, is_verified=True,
            )
        user.is_platform_admin = True
        user.save(update_fields=["is_platform_admin"])
        self.stdout.write(self.style.SUCCESS(
            f"{email} is now a platform admin" + (" (new account created)." if created else ".")
        ))
