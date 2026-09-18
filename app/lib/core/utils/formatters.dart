import 'package:intl/intl.dart';

import '../calendar/nepal_time.dart';
import '../calendar/nepali_calendar_service.dart';
import '../constants/app_constants.dart';

/// Display + wire-format helpers shared by every feature module.
class Formatters {
  /// Set by [SettingsProvider] from the "Show Bikram Sambat dates" preference.
  /// When true, [date] and [dateShort] render in the Nepali calendar
  /// app-wide; [apiDate] always stays Gregorian since that's the wire format
  /// the backend expects.
  static bool useNepaliCalendar = false;

  /// Set by [SettingsProvider] from the "Hide amounts" preference. When
  /// true, [currency] masks its value app-wide — [amount] stays visible
  /// since it's used for quantities (units sold, stock count), not money.
  static bool hideAmounts = false;

  static const _maskedAmount = '••••';

  static final _amountFormat = NumberFormat('#,##0.##');
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateShortFormat = DateFormat('dd MMM');
  static final _apiDateFormat = DateFormat('yyyy-MM-dd');

  static const _nepaliDatePattern = 'dd MMM yyyy';
  static const _nepaliDateShortPattern = 'dd MMM';

  /// Everyday give/receive wording for a transaction-feed "type" badge
  /// (Day Book, All Transactions, Cash In Hand, Bank Statement, Party
  /// Ledger) instead of the raw backend enum ("PAYMENT_IN", "BANK_CREDIT",
  /// ...) — matches the "Give"/"Receive" quick-entry shortcuts on the
  /// Dashboard so the same money movement reads the same way everywhere.
  static String transactionTypeLabel(String type) {
    switch (type) {
      case 'SALE':
        return 'Sale';
      case 'SALE_RETURN':
        return 'Sale Return';
      case 'PURCHASE':
        return 'Purchase';
      case 'PURCHASE_RETURN':
        return 'Purchase Return';
      case 'EXPENSE':
        return 'Expense';
      case 'RECEIPT':
      case 'PAYMENT_IN':
        return 'Received';
      case 'PAYMENT_OUT':
        return 'Given';
      case 'BANK_CREDIT':
      case 'CREDIT':
        return 'Bank Credit';
      case 'BANK_DEBIT':
      case 'DEBIT':
        return 'Bank Debit';
      default:
        return type;
    }
  }

  static String currency(num? amount) => hideAmounts
      ? '${AppConstants.defaultCurrency} $_maskedAmount'
      : '${AppConstants.defaultCurrency} ${_amountFormat.format(amount ?? 0)}';

  static String amount(num? value) => _amountFormat.format(value ?? 0);

  /// A date-only value ("2026-09-18") parses to a plain local DateTime and is
  /// shown as-is. A timestamp with a timezone offset ("...T01:45+05:45")
  /// parses to a UTC moment, which must be shown on the *Nepal* calendar —
  /// otherwise something entered at 1:45 AM in Nepal displays yesterday's date.
  static DateTime _nepalDate(DateTime d) => d.isUtc ? NepalTime.fromInstant(d) : d;

  static String date(DateTime? date) {
    if (date == null) return '—';
    date = _nepalDate(date);
    return useNepaliCalendar
        ? NepaliCalendarService.format(date, _nepaliDatePattern)
        : _dateFormat.format(date);
  }

  static String dateShort(DateTime? date) {
    if (date == null) return '—';
    date = _nepalDate(date);
    return useNepaliCalendar
        ? NepaliCalendarService.format(date, _nepaliDateShortPattern)
        : _dateShortFormat.format(date);
  }

  static String apiDate(DateTime date) => _apiDateFormat.format(date);

  static DateTime? parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
