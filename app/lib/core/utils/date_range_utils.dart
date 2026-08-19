/// A closed date range. Both ends null means "no bound" (all time).
class DateRange {
  final DateTime? from;
  final DateTime? to;
  const DateRange(this.from, this.to);
}

enum DateRangePreset { thisMonth, lastMonth, thisYear, allTime, custom }

extension DateRangePresetLabel on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.thisMonth => 'This Month',
        DateRangePreset.lastMonth => 'Last Month',
        DateRangePreset.thisYear => 'This Year',
        DateRangePreset.allTime => 'All Time',
        DateRangePreset.custom => 'Custom Range',
      };
}

class DateRangeUtils {
  /// Day 0 of next month is the last day of this month — a simple trick
  /// that also handles variable month lengths without a lookup table.
  static DateRange forPreset(DateRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.thisMonth:
        return DateRange(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
      case DateRangePreset.lastMonth:
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        return DateRange(DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month, 1), lastDayOfPrevMonth);
      case DateRangePreset.thisYear:
        return DateRange(DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
      case DateRangePreset.allTime:
      case DateRangePreset.custom:
        return const DateRange(null, null);
    }
  }
}
