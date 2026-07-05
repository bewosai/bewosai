import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // ── Server URL ──────────────────────────────────────────────────────────────
  // Web browser (Flutter web)  → 127.0.0.1 (same machine as Django)
  // Android emulator           → 10.0.2.2  (maps to host 127.0.0.1)
  // Physical device            → your LAN IP, e.g. 192.168.1.5
  static const String _webUrl      = 'http://127.0.0.1:8000/api';
  static const String _emulatorUrl = 'http://10.0.2.2:8000/api';
  static const String _deviceUrl   = 'http://10.0.2.2:8000/api'; // change to LAN IP for physical device
  static const bool   _isEmulator  = true;                        // set false when using a real phone

  static String get baseUrl {
    if (kIsWeb) return _webUrl;
    return _isEmulator ? _emulatorUrl : _deviceUrl;
  }

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser = 'user_data';
  static const String keyCurrentBusiness = 'current_business';
  static const String keyBusinessId = 'business_id';
  static const String keyTheme = 'app_theme';
  static const String keyLanguage = 'app_language';
  static const String keyPrivateMode = 'private_mode';
  static const String keyDateMode = 'date_mode';
  static const String keyCurrency = 'currency';

  // Currency
  static const String defaultCurrency = 'Rs.';
}
