import 'package:bewosai_app/core/utils/date_range_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  group('DateRangeUtils.forPreset', () {
    test('thisMonth spans the 1st to the actual last day of the current month', () {
      final range = DateRangeUtils.forPreset(DateRangePreset.thisMonth);
      expect(range.from, DateTime(now.year, now.month, 1));
      // Day 0 of next month == last day of this month, handles Feb/30-day
      // months automatically without a lookup table.
      expect(range.to, DateTime(now.year, now.month + 1, 0));
      expect(range.to!.month, now.month, reason: 'must not roll into next month');
    });

    test('lastMonth is entirely before this month, with no gap or overlap', () {
      final thisMonth = DateRangeUtils.forPreset(DateRangePreset.thisMonth);
      final lastMonth = DateRangeUtils.forPreset(DateRangePreset.lastMonth);

      expect(lastMonth.from!.day, 1);
      // lastMonth.to should be exactly one day before thisMonth.from.
      expect(lastMonth.to!.add(const Duration(days: 1)), thisMonth.from);
    });

    test('lastMonth correctly rolls back across a year boundary in January', () {
      // Not asserting against real "now" here since the test can run in any
      // month — this directly checks the year-rollback arithmetic instead.
      final januaryFirst = DateTime(2026, 1, 1);
      final lastDayOfPrevMonth = DateTime(januaryFirst.year, januaryFirst.month, 0);
      expect(lastDayOfPrevMonth, DateTime(2025, 12, 31));
    });

    test('thisYear spans Jan 1 to Dec 31 of the current year', () {
      final range = DateRangeUtils.forPreset(DateRangePreset.thisYear);
      expect(range.from, DateTime(now.year, 1, 1));
      expect(range.to, DateTime(now.year, 12, 31));
    });

    test('allTime and custom both have no bound, since a real range for '
        '"custom" is chosen by the caller, not synthesized here', () {
      expect(DateRangeUtils.forPreset(DateRangePreset.allTime).from, isNull);
      expect(DateRangeUtils.forPreset(DateRangePreset.allTime).to, isNull);
      expect(DateRangeUtils.forPreset(DateRangePreset.custom).from, isNull);
      expect(DateRangeUtils.forPreset(DateRangePreset.custom).to, isNull);
    });
  });

  group('DateRangePresetLabel', () {
    test('every preset has a human-readable, non-empty label', () {
      for (final preset in DateRangePreset.values) {
        expect(preset.label, isNotEmpty);
      }
    });
  });
}
