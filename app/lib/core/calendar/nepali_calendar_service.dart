import 'package:nepali_utils/nepali_utils.dart';
import './nepal_time.dart';

/// Bikram Sambat (Nepali calendar) helpers, used by the Settings screen's
/// "Show Bikram Sambat dates" toggle.
///
/// AD->BS deliberately does NOT use the package's `DateTime.toNepaliDateTime()`.
/// That method's result depends on the *device's timezone database*: it
/// subtracts local `DateTime`s from 1913 and then adds a day only when the
/// device timezone is exactly +5:45, to cover Nepal's 1986 clock change. Phones
/// (Android's tz data has that change) and Windows (it doesn't) therefore
/// disagree by one day, so any fixed offset applied on top is wrong on one of
/// them — that's how the app once showed Ashwin 4 on a phone when it was Ashwin 5.
///
/// The package's BS->AD direction ([NepaliDateTime.toDateTime]) is plain
/// calendar arithmetic with no timezone in it, so AD->BS is built from that:
/// find the BS month that starts on or before the date, and count days from
/// there, using UTC day numbers. The answer is the same on every device.
class NepaliCalendarService {
  // The package's calendar table covers these BS years.
  static const _firstBsYear = 2000;
  static const _lastBsYear = 2099;

  /// The calendar day of [year]-[month]-[day] as a UTC date, so differences
  /// between two of them are whole days whatever the device timezone is.
  static DateTime _utcDay(int year, int month, int day) => DateTime.utc(year, month, day);

  static NepaliDateTime _toNepali(DateTime date) {
    final target = _utcDay(date.year, date.month, date.day);
    // A BS year is 56 or 57 ahead of the AD year (Baishakh starts mid-April),
    // so the answer is in one of these two — try the later one first.
    for (final bsYear in [date.year + 57, date.year + 56]) {
      if (bsYear < _firstBsYear || bsYear > _lastBsYear) continue;
      for (var month = 12; month >= 1; month--) {
        final startAd = NepaliDateTime(bsYear, month, 1).toDateTime();
        final start = _utcDay(startAd.year, startAd.month, startAd.day);
        if (!start.isAfter(target)) {
          return NepaliDateTime(bsYear, month, target.difference(start).inDays + 1);
        }
      }
    }
    throw RangeError('$date is outside the supported Bikram Sambat range '
        '($_firstBsYear-$_lastBsYear BS).');
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

  /// BS->AD conversion (the package's own, which has no timezone dependence).
  static DateTime toGregorian(NepaliDateTime date) => date.toDateTime();
}
