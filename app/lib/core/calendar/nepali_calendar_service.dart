import 'package:nepali_utils/nepali_utils.dart';
import './bs_calendar_table.dart';
import './nepal_time.dart';

/// Bikram Sambat (Nepali calendar) helpers, used by the Settings screen's
/// "Show Bikram Sambat dates" toggle and the BS date picker.
///
/// Every conversion here is plain calendar arithmetic over our own month-length
/// table ([bsMonthDays]) — no timezone and no `nepali_utils` conversion is
/// involved. The package is only used for its `NepaliDateTime` value type and
/// for formatting month names. Two reasons for not trusting its conversions:
///
///  * `DateTime.toNepaliDateTime()` depends on the device's timezone database
///    (it adds a day only when the timezone is +5:45, to cover Nepal's 1986
///    clock change), so Windows and Android phones disagree by a day — that's
///    how the app once showed Ashwin 4 on a phone when it was Ashwin 5.
///  * Its month-length table is wrong from BS 2084: it puts Baishakh 1, 2085
///    on 14 Apr 2028, where the published calendar has 13 Apr.
///
/// Anchor: Baishakh 1, 2083 BS = 14 Apr 2026 AD (published, and confirmed
/// against Hamro Patro). Other years are reached by adding/subtracting the
/// table's month lengths.
class NepaliCalendarService {
  static const firstBsYear = 2000;
  static const lastBsYear = 2099;

  static const _anchorYear = 2083;
  static final _anchorDay = _dayNumber(2026, 4, 14);

  /// Whole days since 1970-01-01 for a calendar date, timezone-free.
  static int _dayNumber(int year, int month, int day) =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static int _yearLength(int bsYear) => bsMonthDays[bsYear]!.fold(0, (a, b) => a + b);

  /// Day number of Baishakh 1 for every supported BS year (index = year - 2000),
  /// plus one entry past the end so a year's length is next start minus its own.
  static final List<int> _yearStarts = _buildYearStarts();

  static List<int> _buildYearStarts() {
    final starts = List<int>.filled(lastBsYear - firstBsYear + 2, 0);
    starts[_anchorYear - firstBsYear] = _anchorDay;
    for (var y = _anchorYear + 1; y <= lastBsYear + 1; y++) {
      starts[y - firstBsYear] = starts[y - 1 - firstBsYear] + _yearLength(y - 1);
    }
    for (var y = _anchorYear - 1; y >= firstBsYear; y--) {
      starts[y - firstBsYear] = starts[y + 1 - firstBsYear] - _yearLength(y);
    }
    return starts;
  }

  static void _checkYear(int bsYear) {
    if (bsYear < firstBsYear || bsYear > lastBsYear) {
      throw RangeError('BS year $bsYear is outside the supported $firstBsYear-$lastBsYear.');
    }
  }

  /// Number of days in the given BS month (1-12).
  static int daysInMonth(int bsYear, int bsMonth) {
    _checkYear(bsYear);
    return bsMonthDays[bsYear]![bsMonth - 1];
  }

  /// Weekday of the 1st of the given BS month: Sunday = 1 ... Saturday = 7.
  static int firstWeekday(int bsYear, int bsMonth) {
    final ad = toGregorian(NepaliDateTime(bsYear, bsMonth, 1));
    return DateTime.utc(ad.year, ad.month, ad.day).weekday % 7 + 1; // Dart: Mon=1 .. Sun=7
  }

  static NepaliDateTime _toNepali(DateTime date) {
    final n = _dayNumber(date.year, date.month, date.day);
    if (n < _yearStarts.first || n >= _yearStarts.last) {
      throw RangeError('$date is outside the supported Bikram Sambat range '
          '($firstBsYear-$lastBsYear BS).');
    }
    // Last year whose Baishakh 1 is on or before the date.
    var lo = 0, hi = _yearStarts.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_yearStarts[mid] <= n) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final bsYear = firstBsYear + lo;
    var remaining = n - _yearStarts[lo];
    final months = bsMonthDays[bsYear]!;
    var month = 0;
    while (remaining >= months[month]) {
      remaining -= months[month];
      month++;
    }
    return NepaliDateTime(bsYear, month + 1, remaining + 1);
  }

  static String today() => _toNepali(NepalTime.now()).format('MMMM d, yyyy');

  static String fromDateTime(DateTime date) =>
      _toNepali(date).format('MMMM d, yyyy');

  /// Formats [date] as a Bikram Sambat string using an intl-style pattern
  /// (e.g. `'dd MMM yyyy'`, `'dd MMM'`) — mirrors [Formatters]'s AD patterns.
  static String format(DateTime date, String pattern) =>
      _toNepali(date).format(pattern);

  /// Public AD->BS conversion for widgets that need the actual [NepaliDateTime]
  /// rather than a formatted string — e.g. the BS date picker.
  static NepaliDateTime toNepali(DateTime date) => _toNepali(date);

  /// BS->AD conversion. The result is a plain local date at midnight.
  static DateTime toGregorian(NepaliDateTime date) {
    _checkYear(date.year);
    final months = bsMonthDays[date.year]!;
    var n = _yearStarts[date.year - firstBsYear];
    for (var m = 0; m < date.month - 1; m++) {
      n += months[m];
    }
    n += date.day - 1;
    final utc = DateTime.utc(1970, 1, 1).add(Duration(days: n));
    return DateTime(utc.year, utc.month, utc.day);
  }
}
