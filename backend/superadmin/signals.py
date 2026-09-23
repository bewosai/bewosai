"""
Populates ActivityLog automatically for a curated set of models, via Django's
post_save/post_delete signals — connected once in SuperadminConfig.ready()
instead of adding logging calls to every app's views. This keeps existing
business logic completely untouched (no regression risk there) at the cost
of only covering create/delete events: an in-place update (e.g. editing a
Sale) isn't logged — internal saves like payment reconciliation would flood
the feed. A delete is logged both when it's permanent (a real .delete(), e.g.
from the Recycle Bin) and when it's the normal *soft* delete (is_deleted
flipping False -> True on a .save(), which is how the apps delete).

Each tracked model resolves to a (business, user, label) triple; models
without a created_by field (Product, Party, BankAccount) still get a
business-level entry with user=None rather than being skipped entirely.

The same hook also writes accounts.StaffActivity — the business-facing
"who changed what, and when" log (see that model's docstring) — including,
unlike ActivityLog, in-place edits: WATCHED_FIELDS names the handful of
user-visible fields per model worth diffing, so a routine internal re-save
(recomputing a total, say) that touches none of them produces no entry.
"""

# Which permission module (accounts.StaffMemberSerializer's PERMISSION_MODULES,
# the same keys bewosai.permissions.staff_can checks) each tracked model
# belongs to — mirrors purchases.views._RECYCLE_MODULE, which does the same
# mapping for the Recycle Bin.
MODULE_OF = {
    "Sale": "sales", "Quotation": "sales", "Purchase": "purchases", "Expense": "expenses",
    "Party": "parties", "PartyPayment": "payments", "Product": "inventory",
    "BankAccount": "banking", "BankTransaction": "banking",
}

# The fields on each model worth telling an owner about when they change —
# deliberately not every field: internal/computed ones (a Sale's recomputed
# total, timestamps, soft-delete bookkeeping) would just be noise, and are
# left out so a save that only recomputes them logs nothing.
WATCHED_FIELDS = {
    "Sale": ["status", "payment_method", "paid_amount", "discount", "tax_rate", "due_date", "notes", "customer_id"],
    "Quotation": ["status", "discount", "expiry_date", "customer_id"],
    "Purchase": ["status", "payment_method", "paid_amount", "discount", "tax_rate", "due_date", "notes", "supplier_id"],
    "Expense": ["amount", "category_id", "date", "description", "payment_method"],
    "Party": ["name", "phone", "address", "party_type", "opening_balance"],
    "PartyPayment": ["amount", "payment_method", "date", "payment_type"],
    "Product": ["name", "sale_price", "purchase_price", "stock_quantity", "low_stock_threshold", "is_active"],
    "BankAccount": ["account_name", "opening_balance", "is_active"],
    "BankTransaction": ["amount", "transaction_type", "date", "description"],
}

# Read-friendly names for watched fields whose raw name wouldn't mean much on
# its own (e.g. "customer_id") — anything not listed just gets its field name
# with underscores turned into spaces and title-cased.
FIELD_LABELS = {
    "customer_id": "Customer", "supplier_id": "Supplier", "category_id": "Category",
    "paid_amount": "Amount paid", "tax_rate": "Tax rate", "due_date": "Due date",
    "expiry_date": "Expiry date", "payment_method": "Payment method", "payment_type": "Direction",
    "party_type": "Party type", "opening_balance": "Opening balance", "sale_price": "Sale price",
    "purchase_price": "Purchase price", "stock_quantity": "Stock quantity",
    "low_stock_threshold": "Low stock alert level", "is_active": "Active", "account_name": "Account name",
    "transaction_type": "Type",
}


def _business_of(model_name, instance):
    if model_name == "PartyPayment":
        return instance.party.business
    if model_name == "BankTransaction":
        return instance.account.business
    return instance.business


def _label_of(model_name, instance):
    if model_name == "Sale":
        return f"Invoice {instance.invoice_number}"
    if model_name == "Purchase":
        return f"Purchase {instance.bill_number}"
    if model_name == "Expense":
        return f"Expense Rs.{instance.amount}"
    if model_name == "Quotation":
        return f"Quotation {instance.quotation_number}"
    if model_name == "PartyPayment":
        direction = "Received from" if instance.payment_type == "IN" else "Paid to"
        return f"{direction} {instance.party.name}: Rs.{instance.amount}"
    if model_name == "BankTransaction":
        return f"{instance.get_transaction_type_display()} Rs.{instance.amount} ({instance.account.account_name})"
    if model_name == "Product":
        return f"Product: {instance.name}"
    if model_name == "Party":
        return f"Party: {instance.name}"
    if model_name == "BankAccount":
        return f"Account: {instance.account_name}"
    return str(instance)


def _log(action, sender, instance):
    from .models import ActivityLog

    model_name = sender.__name__
    business = _business_of(model_name, instance)
    if business is None:
        return  # e.g. a Party/Sale whose FK was already nulled out mid-cascade
    ActivityLog.objects.create(
        business=business,
        user=getattr(instance, "created_by", None),
        action=action,
        model_name=model_name,
        object_repr=_label_of(model_name, instance)[:255],
    )


def _field_label(field_name):
    return FIELD_LABELS.get(field_name, field_name.removesuffix("_id").replace("_", " ").capitalize())


def _display(model_cls, field_name, value):
    """A field's value as an owner would want to read it — a choice field's
    label rather than its stored code, blank/None as an em dash, everything
    else as a plain string."""
    if value in (None, ""):
        return "—"
    try:
        field = model_cls._meta.get_field(field_name)
    except Exception:
        field = None
    choices = dict(getattr(field, "flatchoices", []) or [])
    if value in choices:
        return str(choices[value])
    if isinstance(value, bool):
        return "Yes" if value else "No"
    return str(value)


def _staff_activity(action, sender, instance, *, changes=None, old_data=None, new_data=None):
    from accounts.models import StaffActivity
    from bewosai.audit import get_current_user

    model_name = sender.__name__
    module = MODULE_OF.get(model_name)
    if not module:
        return
    business = _business_of(model_name, instance)
    if business is None:
        return
    label = _label_of(model_name, instance)[:200]
    verb = {"CREATED": "Created", "UPDATED": "Updated", "DELETED": "Deleted"}[action]
    description = f"{verb} {label}"
    if changes:
        description += " — " + "; ".join(changes)
    # Prefer the row's own created_by (set from request.user by the view before
    # save, on models that have one) and fall back to the request's current
    # user — needed for Product/Party/BankAccount, which have no created_by
    # field at all, and harmless everywhere else.
    StaffActivity.objects.create(
        user=getattr(instance, "created_by", None) or get_current_user(),
        business=business,
        action={"CREATED": StaffActivity.ACTION_CREATE, "UPDATED": StaffActivity.ACTION_UPDATE,
                "DELETED": StaffActivity.ACTION_DELETE}[action],
        module=module,
        description=description[:2000],
        object_type=model_name,
        object_id=instance.pk,
        object_repr=label,
        old_data=old_data or {},
        new_data=new_data or {},
    )


def _remember_old_state(sender, instance, **kwargs):
    # Stash, before the save actually happens: (a) whether this row was
    # already soft-deleted, so post_save can tell a fresh delete from an
    # unrelated edit of an already-deleted row, and (b) the current DB value
    # of every watched field, so post_save can diff against what's about to
    # be written. Only for existing rows — nothing to compare a new row against.
    if instance.pk is None:
        return
    row = sender._base_manager.filter(pk=instance.pk).values(
        *(["is_deleted"] if hasattr(instance, "is_deleted") else []),
        *WATCHED_FIELDS.get(sender.__name__, []),
    ).first()
    instance._activity_old = row


def _on_saved(sender, instance, created, **kwargs):
    model_name = sender.__name__
    old = getattr(instance, "_activity_old", None)
    was_deleted = old.get("is_deleted") if old and "is_deleted" in old else None

    if created:
        _log("CREATED", sender, instance)
        _staff_activity("CREATED", sender, instance)
    elif was_deleted is False and getattr(instance, "is_deleted", False):
        _log("DELETED", sender, instance)
        _staff_activity("DELETED", sender, instance)
    elif old is not None:
        # An in-place edit (not a fresh create, not a delete) — diff the
        # fields this model watches; nothing here if none of them changed.
        changes, old_data, new_data = [], {}, {}
        for field in WATCHED_FIELDS.get(model_name, []):
            old_val, new_val = old.get(field), getattr(instance, field, None)
            if old_val != new_val:
                old_disp, new_disp = _display(sender, field, old_val), _display(sender, field, new_val)
                changes.append(f"{_field_label(field)}: {old_disp} → {new_disp}")
                old_data[field], new_data[field] = old_disp, new_disp
        if changes:
            _staff_activity("UPDATED", sender, instance, changes=changes, old_data=old_data, new_data=new_data)

    if hasattr(instance, "_activity_old"):
        del instance._activity_old


def _on_deleted(sender, instance, **kwargs):
    _log("DELETED", sender, instance)
    _staff_activity("DELETED", sender, instance)


# Every model whose creation/permanent-deletion should appear in Super
# Admin's activity feed. Add an entry here (and, if it needs a custom label,
# to _label_of above) rather than editing that app's own views.
TRACKED_APP_MODELS = [
    ("sales", "Sale"),
    ("sales", "Quotation"),
    ("purchases", "Purchase"),
    ("expenses", "Expense"),
    ("parties", "Party"),
    ("parties", "PartyPayment"),
    ("inventory", "Product"),
    ("banking", "BankAccount"),
    ("banking", "BankTransaction"),
]


def connect():
    """
    Called from SuperadminConfig.ready(). Models are looked up by app
    label/name via Django's app registry (not imported directly) since
    ready() runs during app loading, before cross-app model imports are
    safe everywhere.
    """
    from django.apps import apps
    from django.db.models.signals import pre_save, post_save, post_delete

    for app_label, model_name in TRACKED_APP_MODELS:
        model = apps.get_model(app_label, model_name)
        pre_save.connect(_remember_old_state, sender=model, dispatch_uid=f"activitylog_presave_{app_label}_{model_name}")
        post_save.connect(_on_saved, sender=model, dispatch_uid=f"activitylog_save_{app_label}_{model_name}")
        post_delete.connect(_on_deleted, sender=model, dispatch_uid=f"activitylog_delete_{app_label}_{model_name}")
