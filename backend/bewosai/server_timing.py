"""
Adds a Server-Timing header to every response, e.g.

    Server-Timing: app;dur=182, db;dur=41;desc="7 queries"

`app` is the whole request inside Django, `db` the time spent running queries.
Whatever `app` has on top of `db` is Python work plus opening a database
connection — so when a page is slow in production this says which it is,
from outside, with a plain `curl -I`, instead of guessing.
"""
import time

from django.db import connection


class ServerTimingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        db = {"count": 0, "seconds": 0.0}

        def timed(execute, sql, params, many, context):
            started = time.perf_counter()
            try:
                return execute(sql, params, many, context)
            finally:
                db["count"] += 1
                db["seconds"] += time.perf_counter() - started

        started = time.perf_counter()
        with connection.execute_wrapper(timed):
            response = self.get_response(request)
        total_ms = (time.perf_counter() - started) * 1000
        response["Server-Timing"] = (
            f'app;dur={total_ms:.0f}, db;dur={db["seconds"] * 1000:.0f};desc="{db["count"]} queries"'
        )
        return response
