import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';
  bool _privateMode = false;
  String _dateMode = 'AD';
  String _currency = AppConstants.defaultCurrency;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get privateMode => _privateMode;
  String get dateMode => _dateMode;
  String get currency => _currency;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(AppConstants.keyTheme) ?? 'light';
    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _language = prefs.getString(AppConstants.keyLanguage) ?? 'en';
    _privateMode = prefs.getBool(AppConstants.keyPrivateMode) ?? false;
    _dateMode = prefs.getString(AppConstants.keyDateMode) ?? 'AD';
    _currency =
        prefs.getString(AppConstants.keyCurrency) ?? AppConstants.defaultCurrency;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.keyTheme, mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLanguage, lang);
    notifyListeners();
  }

  Future<void> togglePrivateMode() async {
    _privateMode = !_privateMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPrivateMode, _privateMode);
    notifyListeners();
  }

  Future<void> setDateMode(String mode) async {
    _dateMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDateMode, mode);
    notifyListeners();
  }

  Future<void> setCurrency(String cur) async {
    _currency = cur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCurrency, cur);
    notifyListeners();
  }

  String formatAmount(double amount) {
    if (_privateMode) return 'XXXXX';
    return '$_currency ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String t(String key) => AppTranslations.get(key, _language);
}

class AppTranslations {
  static const Map<String, Map<String, String>> _data = {
    'en': {
      'dashboard': 'Dashboard',
      'sales': 'Sales',
      'purchases': 'Purchases',
      'expenses': 'Expenses',
      'inventory': 'Inventory',
      'parties': 'Parties',
      'payments': 'Payments',
      'banking': 'Banking',
      'reports': 'Reports',
      'staff': 'Staff',
      'settings': 'Settings',
      'recycle_bin': 'Recycle Bin',
      'logout': 'Logout',
      'new_invoice': 'New Invoice',
      'new_purchase': 'New Purchase',
      'new_expense': 'New Expense',
      'new_party': 'New Party',
      'today_sales': "Today's Sales",
      'month_sales': 'This Month Sales',
      'total_expenses': 'Total Expenses',
      'net_profit': 'Net Profit',
      'receivable': 'Receivable',
      'payable': 'Payable',
      'low_stock': 'Low Stock',
      'recent_sales': 'Recent Sales',
      'profit_loss': 'Profit / Loss',
      'invoice': 'Invoice',
      'invoice_number': 'Invoice #',
      'customer': 'Customer',
      'supplier': 'Supplier',
      'date': 'Date',
      'due_date': 'Due Date',
      'amount': 'Amount',
      'total': 'Total',
      'paid': 'Paid',
      'balance': 'Balance',
      'status': 'Status',
      'confirmed': 'Confirmed',
      'draft': 'Draft',
      'cancelled': 'Cancelled',
      'overdue': 'Overdue',
      'cash': 'Cash',
      'bank': 'Bank Transfer',
      'credit': 'Credit',
      'notes': 'Notes',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'no_data': 'No data found',
      'loading': 'Loading...',
      'all': 'All',
      'customers': 'Customers',
      'suppliers': 'Suppliers',
      'products': 'Products',
      'units': 'Units',
      'category': 'Category',
      'stock': 'Stock',
      'buy_price': 'Buy Price',
      'sell_price': 'Sell Price',
      'language': 'Language',
      'theme': 'Theme',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'date_format': 'Date Format',
      'private_mode': 'Private Mode',
      'business_info': 'Business Info',
      'save_settings': 'Save Settings',
      'revenue': 'Revenue',
      'profit': 'Profit',
      'loss': 'Loss',
      'delete_confirm': 'Are you sure you want to delete?',
      'restore': 'Restore',
      'permanent_delete': 'Permanent Delete',
      'recycle_bin_empty': 'Recycle bin is empty',
      'quotation': 'Quotation',
      'sales_return': 'Sales Return',
      'share_whatsapp': 'Share via WhatsApp',
      'print_invoice': 'Print Invoice',
      'send_otp': 'Send OTP',
      'verify_otp': 'Verify OTP',
      'resend_otp': 'Resend OTP',
      'welcome': 'Welcome to Bewosy',
      'choose_profile': 'Choose your profile',
      'business_profile': 'Business',
      'personal_profile': 'Personal Finance',
      'more': 'More',
    },
    'ne': {
      'dashboard': 'ड्यासबोर्ड',
      'sales': 'बिक्री',
      'purchases': 'खरिद',
      'expenses': 'खर्च',
      'inventory': 'भण्डार',
      'parties': 'पार्टीहरू',
      'payments': 'भुक्तानी',
      'banking': 'बैंकिङ',
      'reports': 'प्रतिवेदन',
      'staff': 'कर्मचारी',
      'settings': 'सेटिङ',
      'recycle_bin': 'रद्दी टोकरी',
      'logout': 'बाहिर निस्कनुहोस्',
      'new_invoice': 'नयाँ बिजक',
      'new_purchase': 'नयाँ खरिद',
      'new_expense': 'नयाँ खर्च',
      'new_party': 'नयाँ पार्टी',
      'today_sales': 'आजको बिक्री',
      'month_sales': 'यो महिना बिक्री',
      'total_expenses': 'कुल खर्च',
      'net_profit': 'खुद नाफा',
      'receivable': 'पाउनु पर्ने',
      'payable': 'तिर्नु पर्ने',
      'low_stock': 'कम स्टक',
      'recent_sales': 'हालका बिक्री',
      'profit_loss': 'नाफा / घाटा',
      'invoice': 'बिजक',
      'invoice_number': 'बिजक नं.',
      'customer': 'ग्राहक',
      'supplier': 'आपूर्तिकर्ता',
      'date': 'मिति',
      'due_date': 'भुक्तानी मिति',
      'amount': 'रकम',
      'total': 'जम्मा',
      'paid': 'तिरिएको',
      'balance': 'मौज्दात',
      'status': 'अवस्था',
      'confirmed': 'पुष्टि',
      'draft': 'मस्यौदा',
      'cancelled': 'रद्द',
      'overdue': 'म्याद नाघेको',
      'cash': 'नगद',
      'bank': 'बैंक ट्रान्सफर',
      'credit': 'उधारो',
      'notes': 'टिप्पणी',
      'save': 'सुरक्षित',
      'cancel': 'रद्द',
      'delete': 'मेटाउनुहोस्',
      'edit': 'सम्पादन',
      'search': 'खोज्नुहोस्',
      'no_data': 'डेटा भेटिएन',
      'loading': 'लोड हुँदैछ...',
      'all': 'सबै',
      'customers': 'ग्राहकहरू',
      'suppliers': 'आपूर्तिकर्ताहरू',
      'products': 'उत्पादनहरू',
      'units': 'एकाइहरू',
      'category': 'वर्ग',
      'stock': 'स्टक',
      'buy_price': 'खरिद मूल्य',
      'sell_price': 'बिक्री मूल्य',
      'language': 'भाषा',
      'theme': 'थिम',
      'light_mode': 'उज्यालो मोड',
      'dark_mode': 'अँध्यारो मोड',
      'date_format': 'मिति ढाँचा',
      'private_mode': 'निजी मोड',
      'business_info': 'व्यवसाय जानकारी',
      'save_settings': 'सेटिङ सुरक्षित',
      'revenue': 'आम्दानी',
      'profit': 'नाफा',
      'loss': 'घाटा',
      'delete_confirm': 'के तपाईं मेटाउन चाहनुहुन्छ?',
      'restore': 'पुनर्स्थापना',
      'permanent_delete': 'स्थायी मेटाउनुहोस्',
      'recycle_bin_empty': 'रद्दी टोकरी खाली छ',
      'quotation': 'कोटेशन',
      'sales_return': 'बिक्री फिर्ता',
      'share_whatsapp': 'WhatsApp मार्फत साझा',
      'print_invoice': 'बिजक छाप्नुहोस्',
      'send_otp': 'OTP पठाउनुहोस्',
      'verify_otp': 'OTP प्रमाणित',
      'resend_otp': 'OTP पुन: पठाउनुहोस्',
      'welcome': 'Bewosy मा स्वागत छ',
      'choose_profile': 'आफ्नो प्रोफाइल छान्नुहोस्',
      'business_profile': 'व्यवसाय',
      'personal_profile': 'व्यक्तिगत वित्त',
      'more': 'थप',
    },
  };

  static String get(String key, String lang) {
    return _data[lang]?[key] ?? _data['en']?[key] ?? key;
  }
}
