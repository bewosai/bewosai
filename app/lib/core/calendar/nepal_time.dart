/// Nepal Standard Time (Asia/Kathmandu): UTC+5:45 all year, no daylight saving.
///
/// Business dates ("today" on a new invoice, the dashboard's month range, ...)
/// follow Nepal time rather than whatever timezone the phone is set to, so
/// they're right even on a phone with the wrong timezone (or one that's
/// travelling), and the same as what the server and website use.
class NepalTime {
  NepalTime._();

  static const offset = Duration(hours: 5, minutes: 45);

  /// The current moment as Nepal wall-clock time. The result is a plain
  /// (non-UTC) [DateTime] whose year/month/day/hour/minute fields *are* the
  /// Nepal fields — use it for "today" defaults and date arithmetic.
  static DateTime now() => fromInstant(DateTime.now());

  /// Today's date in Nepal, at midnight.
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Converts an exact moment (e.g. a server timestamp) to Nepal wall-clock
  /// time, whichever timezone the phone is in.
  static DateTime fromInstant(DateTime instant) {
    final n = instant.toUtc().add(offset);
    return DateTime(n.year, n.month, n.day, n.hour, n.minute, n.second, n.millisecond);
  }
}
