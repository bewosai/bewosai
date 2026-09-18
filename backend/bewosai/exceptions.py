from rest_framework.exceptions import Throttled
from rest_framework.views import exception_handler


def _wait_text(seconds):
    seconds = int(seconds or 0)
    if seconds <= 90:
        return f"{max(seconds, 1)} seconds"
    minutes = -(-seconds // 60)  # round up
    return f"{minutes} minutes"


def api_exception_handler(exc, context):
    """
    DRF's default 429 body is "Request was throttled. Expected available in
    3576 seconds." — technical and easy to mistake for the server being broken.
    Say what happened, and for how long, in plain words. The message goes under
    every key the apps read ("message" for the auth endpoints, "detail"/"error"
    elsewhere) so it surfaces wherever the request came from.
    """
    response = exception_handler(exc, context)
    if response is not None and isinstance(exc, Throttled):
        message = f"Too many attempts. Please try again in {_wait_text(exc.wait)}."
        response.data = {"success": False, "message": message, "detail": message, "error": message}
    return response
