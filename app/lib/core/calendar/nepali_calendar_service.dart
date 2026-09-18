import 'package:nepali_utils/nepali_utils.dart';
import './nepal_time.dart';

/// Bikram Sambat (Nepali calendar) helpers, used by the Settings screen's
/// "Show Bikram Sambat dates" toggle.
///
/// nepali_utils 3.0.8's AD->BS conversion (`DateTime.toNepaliDateTime()`) is
/// consistently 1 day ahead of the real calendar — verified against three
/// independently-confirmed anchor dates (BS 2082/1/1 = Apr 14 2025, BS
/// 2083/1/1 = Apr 14 2026, Maghe Sankranti BS 2081/10/1 = Jan 14 2025): the
/// package returns day+1 for all three. Its BS->AD direction
/// (`NepaliDateTime.toDateTime()`) is correct. Subtracting a day before
/// conversion compensates for this and was re-verified to land exactly on
/// all three anchors — see app/bin/nepali_check*.dart (dev scratch scripts)
/// for the verification. Revisit this workaround if the package is upgraded
/// and fixes the underlying bug upstream.
class NepaliCalendarService {
  static NepaliDateTime _toNepali(DateTime date) =>
      date.subtract(const Duration(days: 1)).toNepaliDateTime();

  static String today() => _toNepali(NepalTime.now()).format('MMMM d, yyyy');

  static String fromDateTime(DateTime date) =>
      _toNepali(date).format('MMMM d, yyyy');

  /// Formats [date] as a Bikram Sambat string using an intl-style pattern
  /// (e.g. `'dd MMM yyyy'`, `'dd MMM'`) — mirrors [Formatters]'s AD patterns.
  static String format(DateTime date, String pattern) =>
      _toNepali(date).format(pattern);

  /// Public AD->BS conversion (with the same +1 day bug workaround as the
  /// rest of this service) for widgets that need the actual [NepaliDateTime]
  /// rather than a formatted string — e.g. the BS date picker.
  static NepaliDateTime toNepali(DateTime date) => _toNepali(date);

  /// BS->AD conversion. Unlike [toNepali], the package's own [NepaliDateTime.
  /// toDateTime] direction is correct and needs no offset compensation.
  static DateTime toGregorian(NepaliDateTime date) => date.toDateTime();
}
