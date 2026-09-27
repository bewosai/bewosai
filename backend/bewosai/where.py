"""
Which AWS region is this server closest to, and how far is its database?

Answers "where is the backend actually running?" from the server itself, for
GET /?where=1 — the host dashboard's region label and the network can
disagree, and database round-trip time decides how fast every page is. TCP
connect time to a region's public endpoint is about one network round trip,
so the smallest one is (almost always) the region the server is in. Measured
once per process and remembered; plain GET / stays instant.
"""
import socket
import time
from concurrent.futures import ThreadPoolExecutor

from django.db import connection

REGIONS = {
    "Singapore (ap-southeast-1)": "dynamodb.ap-southeast-1.amazonaws.com",
    "Oregon (us-west-2)": "dynamodb.us-west-2.amazonaws.com",
    "Ohio (us-east-2)": "dynamodb.us-east-2.amazonaws.com",
    "Virginia (us-east-1)": "dynamodb.us-east-1.amazonaws.com",
    "Frankfurt (eu-central-1)": "dynamodb.eu-central-1.amazonaws.com",
    "Mumbai (ap-south-1)": "dynamodb.ap-south-1.amazonaws.com",
}

_result = None


def _connect_ms(host):
    try:
        socket.getaddrinfo(host, 443)  # resolve first so DNS isn't counted
        started = time.perf_counter()
        with socket.create_connection((host, 443), timeout=3):
            return round((time.perf_counter() - started) * 1000, 1)
    except OSError:
        return None


def _database_round_trip_ms():
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")  # opens the connection if needed
            best = None
            for _ in range(3):
                started = time.perf_counter()
                cursor.execute("SELECT 1")
                cursor.fetchone()
                ms = (time.perf_counter() - started) * 1000
                best = ms if best is None else min(best, ms)
            return round(best, 1)
    except Exception:
        return None


def where():
    global _result
    if _result is None:
        with ThreadPoolExecutor(max_workers=len(REGIONS)) as pool:
            timings = dict(zip(REGIONS, pool.map(_connect_ms, REGIONS.values())))
        reachable = {k: v for k, v in timings.items() if v is not None}
        _result = {
            "nearest_region": min(reachable, key=reachable.get) if reachable else None,
            "connect_ms": timings,
            "database_round_trip_ms": _database_round_trip_ms(),
        }
    return _result
