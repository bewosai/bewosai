"""
Shared rules for Excel bulk import (products, parties).

Each row is checked on its own and gets a result the clients can list and
filter: its Excel row number (the header is row 1, so data starts at row 2),
its name, and either "ready"/"created" or "skipped" with the reason. A bad row
is skipped, never the whole file. With dry_run nothing is saved — the clients
use that for the preview, so "Ready" there means exactly what will be created.
"""
import re
from decimal import Decimal, InvalidOperation

from django.db import transaction

MAX_ROWS = 500
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class RowError(Exception):
    """A row can't be imported; the message says why, in plain words."""


def amount(row, field, label, *, default=Decimal("0"), allow_negative=False, blank_is_none=False):
    """A money/quantity cell as a Decimal. Accepts 1200, "1,200", " 1200.50 ".
    Blank → default (or None when blank_is_none)."""
    raw = row.get(field)
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        return None if blank_is_none else default
    text = str(raw).replace(",", "").strip()
    try:
        value = Decimal(text)
    except InvalidOperation:
        raise RowError(f'{label} must be a number (got "{raw}")')
    if not value.is_finite():
        raise RowError(f'{label} must be a number (got "{raw}")')
    if value < 0 and not allow_negative:
        raise RowError(f"{label} can't be negative")
    return value


def email(row, field="email"):
    value = (row.get(field) or "").strip()
    if value and not _EMAIL_RE.match(value):
        raise RowError(f'"{value}" is not a valid email address')
    return value


def run(rows, *, existing_names, noun, clean, create, dry_run):
    """Checks every row (duplicates against `existing_names` and within the
    file, then `clean(row) -> dict`), and unless dry_run, creates the good ones
    with `create(cleaned)`. Returns the API response body."""
    results, skipped_details = [], []
    seen = set()
    created = ready = 0

    for index, row in enumerate(rows):
        excel_row = index + 2
        if not isinstance(row, dict):
            row = {}
        name = str(row.get("name") or "").strip()
        reason = None
        cleaned = None
        if not name:
            reason = "Missing name"
        elif name.lower() in existing_names:
            reason = f'A {noun} named "{name}" already exists'
        elif name.lower() in seen:
            reason = f'"{name}" appears more than once in this file'
        else:
            try:
                cleaned = clean(row)
                cleaned["name"] = name
            except RowError as exc:
                reason = str(exc)

        if cleaned is not None:
            seen.add(name.lower())
            if dry_run:
                ready += 1
                results.append({"row": excel_row, "name": name, "status": "ready"})
                continue
            try:
                with transaction.atomic():
                    create(cleaned)
                created += 1
                results.append({"row": excel_row, "name": name, "status": "created"})
                continue
            except Exception:
                reason = "Couldn't be saved — please check this row's values"

        results.append({"row": excel_row, "name": name, "status": "skipped", "reason": reason})
        skipped_details.append({"row": row, "excel_row": excel_row, "reason": reason})

    body = {"created": created, "skipped": len(skipped_details), "skipped_details": skipped_details, "results": results}
    if dry_run:
        body["ready"] = ready
    return body
