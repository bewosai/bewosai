"""
Gunicorn settings, read automatically from the working directory — the Render
start command (`gunicorn bewosai.wsgi --bind 0.0.0.0:$PORT`) stays as it is.

Without this, gunicorn ran ONE sync worker: requests were handled strictly one
after another, so the ~9 API calls the app makes when it opens queued behind
each other (measured: 4 simultaneous requests finished at 1.2 s, 2.0 s, 2.8 s
and 3.6 s). Nearly all of a request's time is waiting on the database, not CPU
(~5 ms), so threads let other requests run during that wait.

2 processes × 4 threads = up to 8 requests at once. Fits the free instance's
512 MB (each Django process is roughly 100 MB). Override with WEB_CONCURRENCY /
GUNICORN_THREADS environment variables on Render if the instance size changes.
"""
import os

workers = int(os.environ.get("WEB_CONCURRENCY", "2"))
threads = int(os.environ.get("GUNICORN_THREADS", "4"))
worker_class = "gthread"
# A cold database connection across regions can take a few seconds; the
# default 30 s timeout is kept but made explicit here.
timeout = 30
keepalive = 5
