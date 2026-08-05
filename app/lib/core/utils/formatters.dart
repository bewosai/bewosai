import 'package:intl/intl.dart';

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

  static String currency(num? amount) => hideAmounts
      ? '${AppConstants.defaultCurrency} $_maskedAmount'
      : '${AppConstants.defaultCurrency} ${_amountFormat.format(amount ?? 0)}';

  static String amount(num? value) => _amountFormat.format(value ?? 0);

  static String date(DateTime? date) {
    if (date == null) return '—';
    return useNepaliCalendar
        ? NepaliCalendarService.format(date, _nepaliDatePattern)
        : _dateFormat.format(date);
  }

  static String dateShort(DateTime? date) {
    if (date == null) return '—';
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
