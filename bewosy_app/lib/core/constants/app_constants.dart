class AppConstants {
  // Change to your server IP for physical device testing
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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
