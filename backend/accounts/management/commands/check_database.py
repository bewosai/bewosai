"""
Answers the one question that decides whether user data survives a
deploy/restart on Render: is this actually a persistent database, or
temporary disk that gets wiped?

    python manage.py check_database

Run it in the Render Shell. See bewosai/settings.py's own startup warning
for the same check (it only reaches the deploy log, not this readable
summary), and README.md's deploy notes.
"""
import os

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = "Report whether the database is persistent (Postgres via DATABASE_URL) or ephemeral (SQLite on Render)."

    def handle(self, *args, **options):
        engine = settings.DATABASES["default"]["ENGINE"]
        vendor = connection.vendor  # what Django actually connected to, not just the configured engine
        on_render = bool(os.environ.get("RENDER"))
        database_url_set = bool(os.environ.get("DATABASE_URL"))
        name = settings.DATABASES["default"].get("NAME")

        self.stdout.write(f"On Render               : {on_render}")
        self.stdout.write(f"DATABASE_URL env var set: {database_url_set}")
        self.stdout.write(f"Configured engine       : {engine}")
        self.stdout.write(f"Connected vendor        : {vendor}")
        self.stdout.write(f"Database name/path      : {name}")

        with connection.cursor() as cursor:
            cursor.execute("SELECT count(*) FROM accounts_user")
            user_count = cursor.fetchone()[0]
        self.stdout.write(f"Users currently in this database: {user_count}")

        if on_render and vendor == "sqlite":
            self.stdout.write(self.style.ERROR(
                "\nCRITICAL: This is SQLite on Render's disk. That disk is WIPED on every "
                "deploy and every restart (including the free tier spinning down after idle "
                "time) — every user, business, sale, everything, disappears each time, and "
                "signing in again with the same email silently creates a brand-new empty "
                "account instead of failing loudly.\n"
                "Fix: attach a persistent Postgres database in Render (Dashboard -> New -> "
                "PostgreSQL, or use an existing one), then set this service's DATABASE_URL "
                "environment variable to that database's Internal Connection String, and "
                "redeploy. Existing data on the current SQLite disk cannot be recovered — "
                "it's already gone the moment this warning appears."
            ))
        elif vendor == "postgresql":
            self.stdout.write(self.style.SUCCESS("\nPersistent database — data survives deploys and restarts."))
        else:
            self.stdout.write(self.style.WARNING(
                f"\nRunning on {vendor}, not on Render — this is expected for local development."
            ))
