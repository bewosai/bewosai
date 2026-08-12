import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'Bewosai';

  // ── Server URL ──────────────────────────────────────────────────────────
  // Override at build time for a real device / production APK, e.g.:
  //   flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.up.railway.app/api
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.88:8000/api   (physical device, native build)
  // Without that flag, falls back to:
  //   Flutter web  → same host the page was loaded from (so opening the dev
  //                  server's LAN URL from a phone browser auto-targets the
  //                  PC's Django server on port 8000), else 127.0.0.1.
  //   Android emulator / native run → 10.0.2.2 (maps to host 127.0.0.1)
  static const String _prodUrl = String.fromEnvironment('API_BASE_URL');
  static const String _webUrl = 'http://127.0.0.1:8000/api';
  static const String _emulatorUrl = 'http://10.0.2.2:8000/api';

  static String get baseUrl {
    if (_prodUrl.isNotEmpty) return _prodUrl;
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

  static const String defaultCurrency = 'Rs.';

  // Payment methods — sales.Sale / parties.PartyPayment METHOD_CHOICES
  static const List<String> paymentMethods = ['CASH', 'BANK', 'ESEWA', 'KHALTI'];
  static const Map<String, String> paymentMethodLabels = {
    'CASH': 'Cash',
    'BANK': 'Bank',
    'ESEWA': 'eSewa',
    'KHALTI': 'Khalti',
  };

  // Bank account types — banking.BankAccount TYPE_CHOICES
  static const List<String> bankAccountTypes = [
    'CASH',
    'BANK',
    'ESEWA',
    'KHALTI',
    'IME_PAY',
    'MOBILE_BANKING',
    'OTHER',
  ];
  static const Map<String, String> bankAccountTypeLabels = {
    'CASH': 'Cash',
    'BANK': 'Bank',
    'ESEWA': 'eSewa',
    'KHALTI': 'Khalti',
    'IME_PAY': 'IME Pay',
    'MOBILE_BANKING': 'Mobile Banking',
    'OTHER': 'Other',
  };

  // Party types — parties.Party TYPE_CHOICES
  static const List<String> partyTypes = ['CUSTOMER', 'SUPPLIER', 'BOTH'];

  // Staff roles — accounts.StaffMember ROLE_CHOICES
  static const List<String> staffRoles = ['OWNER', 'MANAGER', 'CASHIER', 'VIEWER'];

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
