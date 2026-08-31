"""
Populates ActivityLog automatically for a curated set of models, via Django's
post_save/post_delete signals — connected once in SuperadminConfig.ready()
instead of adding logging calls to every app's views. This keeps existing
business logic completely untouched (no regression risk there) at the cost
of only covering create/permanent-delete events: an in-place update (e.g.
editing a Sale) isn't logged, and a *soft* delete (is_deleted=True, still a
.save()) shows up as nothing rather than a spurious "created" — only a real
.delete() (e.g. from the Recycle Bin's permanent-delete) fires post_delete.

Each tracked model resolves to a (business, user, label) triple; models
without a created_by field (Product, Party, BankAccount) still get a
business-level entry with user=None rather than being skipped entirely.
"""


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


def _on_saved(sender, instance, created, **kwargs):
    if created:
        _log("CREATED", sender, instance)


def _on_deleted(sender, instance, **kwargs):
    _log("DELETED", sender, instance)


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
    from django.db.models.signals import post_save, post_delete

    for app_label, model_name in TRACKED_APP_MODELS:
        model = apps.get_model(app_label, model_name)
        post_save.connect(_on_saved, sender=model, dispatch_uid=f"activitylog_save_{app_label}_{model_name}")
        post_delete.connect(_on_deleted, sender=model, dispatch_uid=f"activitylog_delete_{app_label}_{model_name}")
