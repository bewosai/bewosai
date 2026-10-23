"""
Keeps money and stock right when the same record is changed twice at once —
a double-tapped Delete/Save, a retried request on a slow connection, or two
staff members editing one invoice.

Each write runs in one transaction holding a row lock on the record. The
second request waits for the first, then sees the record as the first left it:
a deleted invoice is gone (404) instead of putting its stock back a second
time, and a paid invoice shows nothing more due.

SQLite (local dev and tests) has no row locks and ignores them; the
transaction still makes each write all-or-nothing. Postgres (live) locks.
"""
from django.db import transaction

WRITE_METHODS = ("PUT", "PATCH", "DELETE")


def lock(queryset):
    """`queryset` with its own rows locked until the transaction ends.

    of=("self",) locks only this table's rows: the views' querysets join the
    business and staff tables to check access, and Postgres refuses FOR UPDATE
    on the nullable side of an outer join (select_related on an optional FK).
    """
    return queryset.select_for_update(of=("self",))


class LockedWritesMixin:
    """For a generics.Retrieve(Update)(Destroy)APIView: PUT/PATCH/DELETE run in
    one transaction that locks the object being changed. Must come before the
    generic view class in the bases.

    An error response (4xx/5xx) rolls the transaction back, so a request
    refused part-way leaves nothing half-written.
    """

    def dispatch(self, request, *args, **kwargs):
        if request.method not in WRITE_METHODS:
            return super().dispatch(request, *args, **kwargs)
        with transaction.atomic():
            response = super().dispatch(request, *args, **kwargs)
            if response.status_code >= 400:
                transaction.set_rollback(True)
            return response

    # Not get_queryset: the views define their own, which would replace this.
    # DRF's get_object passes their queryset through filter_queryset.
    def filter_queryset(self, queryset):
        queryset = super().filter_queryset(queryset)
        if self.request.method in WRITE_METHODS:
            queryset = lock(queryset)
        return queryset
