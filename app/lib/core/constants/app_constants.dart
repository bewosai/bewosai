import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class AppConstants {
  static const String appName = 'Bewosai';
  // Shown in Settings so anyone can tell which APK is installed (every build is
  // version 2.0.0+1). Change it whenever a new APK is built.
  static const String buildLabel = '2026-09-26-a';

  // ── Server URL ──────────────────────────────────────────────────────────
  // Override at build time for a real device / a different backend (e.g.
  // the staging Render service instead of production), or a physical
  // device on the same LAN as the dev machine:
  //   flutter build apk --release --dart-define=API_BASE_URL=https://bewosai-backend-staging.onrender.com/api
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.88:8000/api   (physical device, native build)
  // Without that flag, falls back to:
  //   Release build → the deployed Render backend (_renderUrl below).
  //   Debug, Flutter web → same host the page was loaded from (so opening the
  //                  dev server's LAN URL from a phone browser auto-targets
  //                  the PC's Django server on port 8000), else 127.0.0.1.
  //   Debug, Android emulator / native run → 10.0.2.2 (maps to host 127.0.0.1)
  static const String _prodUrl = String.fromEnvironment('API_BASE_URL');
  static const String _renderUrl = 'https://bewosai-backend-0esi.onrender.com/api';
  static const String _webUrl = 'http://127.0.0.1:8000/api';
  static const String _emulatorUrl = 'http://10.0.2.2:8000/api';

  static String get baseUrl {
    if (_prodUrl.isNotEmpty) return _prodUrl;
    if (kReleaseMode) return _renderUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:8000/api';
      }
      return _webUrl;
    }
    return _emulatorUrl;
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────
  // The OAuth 2.0 *Web* client ID from Google Cloud Console — passed as
  // GoogleSignIn's serverClientId so the ID token it returns is minted for
  // that audience, matching backend.GOOGLE_OAUTH_CLIENT_ID which verifies it.
  // Required to enable Google sign-in; blank disables the button. Set via:
  //   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  // Secure storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';

  // Shared preferences keys (cached, non-sensitive)
  static const String keyUser = 'user_data';
  static const String keyBusinesses = 'businesses_data';
  static const String keyCurrentBusiness = 'current_business';
  // Deliberately NOT wiped by TokenStorage.clear() (full logout) — mirrors
  // the website's `last_business_id` in localStorage, so the next login on
  // this device auto-restores the same business instead of asking again.
  static const String keyLastBusinessId = 'last_business_id';

  static const String defaultCurrency = 'Rs.';

  // Payment methods — sales.Sale / parties.PartyPayment / expenses.Expense
  // METHOD_CHOICES. SPLIT is sales.Sale / purchases.Purchase only (they're
  // the only models with a cash_amount field) — use
  // [paymentMethodsWithSplit] for those two forms, not this list.
  static const List<String> paymentMethods = ['CASH', 'BANK', 'ESEWA', 'KHALTI'];
  static const List<String> paymentMethodsWithSplit = ['CASH', 'BANK', 'ESEWA', 'KHALTI', 'SPLIT'];
  static const Map<String, String> paymentMethodLabels = {
    'CASH': 'Cash',
    'BANK': 'Bank',
    'ESEWA': 'eSewa',
    'KHALTI': 'Khalti',
    'SPLIT': 'Split (Cash + Bank)',
  };

  // Bank account types — banking.BankAccount TYPE_CHOICES
  static const List<String> bankAccountTypes = [
    'CASH',
    'BANK',
    'ESEWA',
    'KHALTI',
    'CONNECT_IPS',
    'IME_PAY',
    'MOBILE_BANKING',
    'OTHER',
  ];
  static const Map<String, String> bankAccountTypeLabels = {
    'CASH': 'Cash',
    'BANK': 'Bank',
    'ESEWA': 'eSewa',
    'KHALTI': 'Khalti',
    'CONNECT_IPS': 'Connect IPS',
    'IME_PAY': 'IME Pay',
    'MOBILE_BANKING': 'Mobile Banking',
    'OTHER': 'Other',
  };

  // How many active accounts of a given type one business may have —
  // mirrors backend/banking/models.py BankAccount.TYPE_LIMITS. Types not
  // listed here (Cash, IME Pay, Mobile Banking, Other) are unlimited.
  static const Map<String, int> bankAccountTypeLimits = {
    'BANK': 2,
    'ESEWA': 1,
    'KHALTI': 1,
    'CONNECT_IPS': 1,
  };

  // Party types — parties.Party TYPE_CHOICES
  static const List<String> partyTypes = ['CUSTOMER', 'SUPPLIER', 'BOTH'];

  // Staff roles — accounts.StaffMember ROLE_CHOICES
  static const List<String> staffRoles = ['OWNER', 'MANAGER', 'CASHIER', 'VIEWER'];

  // A staff member has no email/phone of their own — they sign in purely by
  // opening this link (see accounts.views.StaffLoginView), always served by
  // the web app regardless of which platform the owner shared it from.
  // Mirrors client/src/pages/StaffPage.jsx's staffLoginUrl().
  static const String _webAppUrl = 'https://bewosaiapp.vercel.app';
  static String staffLoginUrl(String token) => '$_webAppUrl/staff-login/$token';

  /// The login token from what a staff member pastes: the full link the owner
  /// shared (`https://.../staff-login/TOKEN`, on any host) or the bare token.
  /// Null when it doesn't look like either.
  static String? staffTokenFromLink(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return null;
    final fromUrl = RegExp(r'/staff-login/([A-Za-z0-9_\-]{20,})').firstMatch(text);
    final token = fromUrl != null ? fromUrl.group(1)! : text;
    // Tokens are secrets.token_urlsafe(32): 43 URL-safe characters, no spaces or slashes.
    return RegExp(r'^[A-Za-z0-9_\-]{20,128}$').hasMatch(token) ? token : null;
  }

  // Stock movement types — inventory.StockMovement TYPE_CHOICES (OPENING is set
  // automatically when a product is created, so it's excluded from manual adjustments)
  static const List<String> stockMovementTypes = [
    'IN',
    'OUT',
    'ADJUSTMENT',
    'DAMAGE',
    'LOST',
    'TRANSFER',
  ];
  static const Map<String, String> stockMovementLabels = {
    'IN': 'Stock In',
    'OUT': 'Stock Out',
    'ADJUSTMENT': 'Adjustment',
    'DAMAGE': 'Damage',
    'LOST': 'Lost',
    'TRANSFER': 'Transfer',
    'OPENING': 'Opening Stock',
  };
}
