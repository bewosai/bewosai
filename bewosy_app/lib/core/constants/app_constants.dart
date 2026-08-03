import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'Bewosy';

  // ── Server URL ──────────────────────────────────────────────────────────
  // Web browser (Flutter web)  → 127.0.0.1 (same machine as Django)
  // Android emulator           → 10.0.2.2  (maps to host 127.0.0.1)
  // Physical device            → your LAN IP, e.g. 192.168.1.5
  static const String _webUrl = 'http://127.0.0.1:8000/api';
  static const String _emulatorUrl = 'http://10.0.2.2:8000/api';
  static const String _deviceUrl = 'http://10.0.2.2:8000/api'; // change to LAN IP for physical device
  static const bool _isEmulator = true; // set false when using a real phone

  static String get baseUrl {
    if (kIsWeb) return _webUrl;
    return _isEmulator ? _emulatorUrl : _deviceUrl;
  }

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
