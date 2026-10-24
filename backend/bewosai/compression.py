"""
Gzip for API responses: JSON lists (sales with their items, reports) shrink to
a fifth or less, which matters on a phone connection in Nepal talking to a
server in the US.

Sign-in responses (/api/auth/…) and Django admin pages are left uncompressed:
they carry tokens or CSRF secrets next to text the caller chose, the mix that
compression-length attacks (BREACH) need — and they're small anyway.
"""
from django.middleware.gzip import GZipMiddleware

SKIP_PREFIXES = ("/api/auth/", "/admin/")


class SelectiveGZipMiddleware(GZipMiddleware):
    def process_response(self, request, response):
        if request.path.startswith(SKIP_PREFIXES):
            return response
        return super().process_response(request, response)
