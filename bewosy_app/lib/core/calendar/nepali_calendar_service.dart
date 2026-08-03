import 'package:nepali_utils/nepali_utils.dart';

/// Bikram Sambat (Nepali calendar) helpers, used by the Settings screen's
/// "Show Bikram Sambat dates" toggle.
class NepaliCalendarService {
  static String today() => NepaliDateTime.now().format('MMMM d, yyyy');

  static String fromDateTime(DateTime date) =>
      date.toNepaliDateTime().format('MMMM d, yyyy');

  /// Formats [date] as a Bikram Sambat string using an intl-style pattern
  /// (e.g. `'dd MMM yyyy'`, `'dd MMM'`) — mirrors [Formatters]'s AD patterns.
  static String format(DateTime date, String pattern) =>
      date.toNepaliDateTime().format(pattern);
}
