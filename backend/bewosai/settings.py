from pathlib import Path
from decouple import config
from datetime import timedelta
import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent

_INSECURE_DEFAULT_KEY = "bewosai-insecure-dev-key-change-in-production"
SECRET_KEY = config("SECRET_KEY", default=_INSECURE_DEFAULT_KEY)
DEBUG = config("DEBUG", default=False, cast=bool)
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="localhost,127.0.0.1,0.0.0.0").split(",")

# Fail loudly rather than silently serving production traffic on a publicly
# known secret key (breaks session/JWT signing security) if SECRET_KEY was
# never set on the host.
if not DEBUG and SECRET_KEY == _INSECURE_DEFAULT_KEY:
    raise RuntimeError(
        "SECRET_KEY is not set. Generate one (e.g. "
        "`python -c \"import secrets; print(secrets.token_urlsafe(50))\"`) "
        "and set it as an environment variable before running with DEBUG=False."
    )

# Render sets RENDER_EXTERNAL_HOSTNAME on the deployed service; trust it
# automatically so ALLOWED_HOSTS doesn't need manual updates after every
# deploy.
_platform_domain = config("RENDER_EXTERNAL_HOSTNAME", default="")
if _platform_domain:
    ALLOWED_HOSTS.append(_platform_domain)

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "django_filters",
    "drf_spectacular",
    # Local apps
    "accounts",
    "inventory",
    "parties",
    "sales",
    "purchases",
    "expenses",
    "banking",
    "reports",
    "superadmin",
    "billing",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Lets superadmin.signals attribute a StaffActivity log entry to whoever
    # made the request, from inside a model signal that has no request.
    "bewosai.audit.CurrentUserMiddleware",
]

ROOT_URLCONF = "bewosai.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "bewosai.wsgi.application"

# Render (and most PaaS hosts) inject DATABASE_URL for the attached Postgres
# instance. Falls back to local SQLite when it's not set (plain `manage.py
# runserver` in dev keeps working unchanged).
DATABASES = {
    "default": dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        # Only forced for Postgres — SQLite has no SSL concept, and requiring
        # it unconditionally (as a plain dj_database_url.parse(..., ssl_require=True)
        # would) breaks every local `manage.py runserver`, which has no
        # DATABASE_URL at all. Matters for Render's *External* database URL
        # (rejected without SSL) and any third-party Postgres host that
        # mandates it; Render's own Internal URL works either way.
        ssl_require=config("DATABASE_URL", default="").startswith("postgres"),
    )
}

# Render sets RENDER=true on its services. There the disk is wiped on every
# deploy/restart, so running on the SQLite fallback silently loses ALL user
# data — say so loudly in the deploy logs instead of failing invisibly.
if config("RENDER", default="", cast=str) and DATABASES["default"]["ENGINE"].endswith("sqlite3"):
    import logging as _logging
    _logging.getLogger("django.security.config").critical(
        "DATABASE_URL is not set: running on SQLite on Render's ephemeral disk. "
        "Every redeploy/restart will ERASE all user data. Attach a Postgres "
        "database and set DATABASE_URL on this service."
    )

AUTH_USER_MODEL = "accounts.User"

# The only place Django's session-based login is used is /admin/ (the app's
# own login is JWT/OTP-based and never touches this) — there's no
# /accounts/profile/ route in this project, so a login whose `next` doesn't
# resolve (Django's LoginView falls back to this default in that case)
# must not land on a 404.
LOGIN_REDIRECT_URL = "/admin/"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Kathmandu"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# Render's filesystem is ephemeral — anything saved to MEDIA_ROOT (product
# images, business logos, purchase bill photos) disappears on every deploy
# or restart. Set CLOUDINARY_URL (from the Cloudinary dashboard's "API
# Environment variable" — looks like cloudinary://<key>:<secret>@<cloud_name>)
# to persist uploads there instead. Without it, uploads just use local disk
# exactly as before, so local dev needs no Cloudinary account.
CLOUDINARY_CONFIGURED = bool(config("CLOUDINARY_URL", default=""))
if CLOUDINARY_CONFIGURED:
    INSTALLED_APPS += ["cloudinary_storage", "cloudinary"]
    STORAGES["default"] = {"BACKEND": "cloudinary_storage.storage.MediaCloudinaryStorage"}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ── Django REST Framework ──────────────────────────────────────────────────────

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "accounts.authentication.TrackedJWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
        "bewosai.permissions.BusinessNotArchivedForWrites",
        "bewosai.permissions.HasActiveSubscription",
    ),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_CLASSES": (
        "rest_framework.throttling.ScopedRateThrottle",
    ),
    # Limits are per IP address, and phone networks / shop or office WiFi put
    # many real people behind one address — 5 code requests an hour used to lock
    # everyone on that address out with "Request was throttled". They're now a
    # backstop against floods only; the real protections are per email (a 60s
    # cooldown and an hourly cap in SendOTPView) and per code (a limit on wrong
    # guesses in OTPCode.verify_and_consume). "otp_verify" is shared by email
    # sign-in, Google sign-in, staff login links and coupons.
    "DEFAULT_THROTTLE_RATES": (
        {"otp_send": "300/hour", "otp_verify": "600/hour"}
        if DEBUG else
        {"otp_send": "40/hour", "otp_verify": "300/hour"}
    ),
    "EXCEPTION_HANDLER": "bewosai.exceptions.api_exception_handler",
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Bewosai API",
    "DESCRIPTION": "Business management platform API for Bewosai — handles sales, inventory, parties, banking, expenses, and reports.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
}

# ── JWT ────────────────────────────────────────────────────────────────────────

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=1),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# ── CORS ───────────────────────────────────────────────────────────────────────
# In development, allow all origins so the Flutter mobile app and Vite web
# client can both reach the API without configuration friction.
# In production, set CORS_ALLOWED_ORIGINS via environment variable.

if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True
else:
    CORS_ALLOWED_ORIGINS = config(
        "CORS_ALLOWED_ORIGINS",
        default="http://localhost:5173,http://127.0.0.1:5173,https://bewosaiapp.vercel.app",
    ).split(",")
    # Vercel gives every preview deployment (per-branch or per-push) its own
    # subdomain, e.g. bewosaiapp-git-<branch>-<team>.vercel.app or
    # bewosaiapp-<hash>-<team>.vercel.app — none of those exact hosts can be
    # listed in CORS_ALLOWED_ORIGINS ahead of time, so match anything under
    # the bewosaiapp project by regex instead of hardcoding each one.
    CORS_ALLOWED_ORIGIN_REGEXES = config(
        "CORS_ALLOWED_ORIGIN_REGEXES",
        default=r"^https://bewosaiapp[a-zA-Z0-9-]*\.vercel\.app$",
    ).split(",")

CORS_ALLOW_CREDENTIALS = True

# Needed for Django's CSRF checks (admin login, session-based requests) to
# accept POSTs originating from the deployed frontend's origin.
CSRF_TRUSTED_ORIGINS = config(
    "CSRF_TRUSTED_ORIGINS",
    default="https://bewosaiapp.vercel.app",
).split(",")
if _platform_domain:
    CSRF_TRUSTED_ORIGINS.append(f"https://{_platform_domain}")

# ── Production security (Render terminates TLS at its edge proxy, so Django
# itself sees plain HTTP — X-Forwarded-Proto tells it the real scheme) ─────────

if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 60 * 60 * 24 * 7  # 1 week; raise once the domain is stable
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True

# Allow the custom header the Flutter app sends for business context
CORS_ALLOW_HEADERS = [
    "accept",
    "accept-encoding",
    "authorization",
    "content-type",
    "dnt",
    "origin",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
    "x-business-id",  # Flutter app business context header
    "x-platform",     # "web" (React) / "mobile" (Flutter) — feature-flag platform targeting
]

# Emails (comma-separated, e.g. "a@x.com,b@y.com") that become platform admins
# (Super Admin) when they sign in — via a verified email code or Google. Kept in
# an environment variable rather than in code so who has admin rights is a
# deployment decision, not something committed to the repo. This only ever
# grants; to take admin away, untick it in Super Admin (or Django admin).
PLATFORM_ADMIN_EMAILS = [
    e.strip().lower() for e in config("PLATFORM_ADMIN_EMAILS", default="").split(",") if e.strip()
]

# Where the website lives — referral links point here (the backend has no pages).
FRONTEND_URL = config("FRONTEND_URL", default="https://bewosaiapp.vercel.app").rstrip("/")

SENDGRID_API_KEY = config("SENDGRID_API_KEY", default="")
SENDGRID_FROM_EMAIL = config("SENDGRID_FROM_EMAIL", default="noreply@bewosai.com")
DEFAULT_FROM_EMAIL = config("DEFAULT_FROM_EMAIL", default="Bewosai <noreply@bewosai.com>")

EMAIL_HOST = config("EMAIL_HOST", default="smtp.gmail.com")
EMAIL_PORT = config("EMAIL_PORT", default=587, cast=int)
EMAIL_USE_TLS = config("EMAIL_USE_TLS", default=True, cast=bool)
EMAIL_HOST_USER = config("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = config("EMAIL_HOST_PASSWORD", default="")
# Without this, a blocked/unresponsive SMTP connection hangs forever instead
# of raising — the gunicorn worker eventually gets killed by its own request
# timeout, turning a recoverable send failure into a raw 500 instead of the
# clean "couldn't send" response send_otp_email's except-block is meant to
# produce.
EMAIL_TIMEOUT = config("EMAIL_TIMEOUT", default=15, cast=int)

# OAuth 2.0 Web client ID from Google Cloud Console — used as the `audience`
# when verifying ID tokens from GoogleLoginView. The Flutter app's
# google_sign_in setup must use a client tied to the same GCP project.
GOOGLE_OAUTH_CLIENT_ID = config("GOOGLE_OAUTH_CLIENT_ID", default="")

# Sparrow SMS (sparrowsms.com) — Nepal-only SMS gateway used to deliver OTP
# codes to +977 phone numbers. SPARROW_TOKEN is the plain v2 API token (from
# the Sparrow dashboard); leave blank to fall back to console logging (dev).
# SPARROW_IDENTITY is the approved sender/purchased identity name shown in
# the dashboard (defaults to "Bewosai" — must match what Sparrow issued you).
SPARROW_TOKEN = config("SPARROW_TOKEN", default="")
SPARROW_IDENTITY = config("SPARROW_IDENTITY", default="Bewosai")

# Auto-select backend: SMTP when Gmail credentials present, console otherwise
EMAIL_BACKEND = (
    "django.core.mail.backends.smtp.EmailBackend"
    if EMAIL_HOST_USER
    else "django.core.mail.backends.console.EmailBackend"
)

# ── Logging ────────────────────────────────────────────────────────────────────

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
