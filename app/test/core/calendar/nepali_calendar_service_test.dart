import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:bewosai_app/core/calendar/nepali_calendar_service.dart';

void main() {
  group('NepaliCalendarService (AD -> BS)', () {
    // Nepali New Year (Baisakh 1) dates that are widely published — the
    // strongest independent check on the conversion and its 1-day workaround.
    final newYears = <int, DateTime>{
      2077: DateTime(2020, 4, 13),
      2078: DateTime(2021, 4, 14),
      2079: DateTime(2022, 4, 14),
      2080: DateTime(2023, 4, 14),
      2081: DateTime(2024, 4, 13),
      2082: DateTime(2025, 4, 14),
      2083: DateTime(2026, 4, 14),
    };

    newYears.forEach((bsYear, ad) {
      test('Baisakh 1, $bsYear is ${ad.toIso8601String().substring(0, 10)}', () {
        final bs = NepaliCalendarService.toNepali(ad);
        expect([bs.year, bs.month, bs.day], [bsYear, 1, 1]);
        // and the day before is the last day of Chaitra of the previous year
        final before = NepaliCalendarService.toNepali(ad.subtract(const Duration(days: 1)));
        expect([before.year, before.month], [bsYear - 1, 12]);
        expect(before.day, inInclusiveRange(29, 32));
      });
    });

    test('round trip AD -> BS -> AD returns the same date for every day 2019-2040', () {
      var day = DateTime(2019, 1, 1);
      final end = DateTime(2040, 12, 31);
      while (!day.isAfter(end)) {
        final back = NepaliCalendarService.toGregorian(NepaliCalendarService.toNepali(day));
        expect(
          DateTime(back.year, back.month, back.day),
          day,
          reason: 'round trip failed for ${day.toIso8601String()}',
        );
        day = day.add(const Duration(days: 1));
      }
    });

    test('consecutive days always advance by exactly one BS day, month or year', () {
      var day = DateTime(2019, 1, 1);
      final end = DateTime(2040, 12, 31);
      var prev = NepaliCalendarService.toNepali(day);
      day = day.add(const Duration(days: 1));
      while (!day.isAfter(end)) {
        final cur = NepaliCalendarService.toNepali(day);
        if (cur.month == prev.month && cur.year == prev.year) {
          expect(cur.day, prev.day + 1, reason: 'skipped/repeated day at ${day.toIso8601String()}');
        } else {
          expect(cur.day, 1, reason: 'new month must start at day 1 at ${day.toIso8601String()}');
          expect(prev.day, inInclusiveRange(29, 32), reason: 'odd month length before ${day.toIso8601String()}');
          final nextMonth = prev.month == 12 ? 1 : prev.month + 1;
          expect(cur.month, nextMonth);
          expect(cur.year, prev.month == 12 ? prev.year + 1 : prev.year);
        }
        prev = cur;
        day = day.add(const Duration(days: 1));
      }
    });

    test('Ashwin 2083: 17 Sep 2026 is Ashwin 1 and 21 Sep 2026 is Ashwin 5 (Hamro Patro)', () {
      for (final c in [
        (DateTime(2026, 9, 17), 1),
        (DateTime(2026, 9, 21), 5),
        (DateTime(2026, 9, 22), 6),
      ]) {
        final bs = NepaliCalendarService.toNepali(c.$1);
        expect([bs.year, bs.month, bs.day], [2083, 6, c.$2], reason: '${c.$1}');
      }
    });

    test('a UTC-flagged or local DateTime for the same calendar day converts the same', () {
      // The result must depend only on the year/month/day, never on the device
      // timezone (the old package call did — one day off on some phones).
      for (final d in [DateTime(2026, 9, 21), DateTime.utc(2026, 9, 21), DateTime(2026, 9, 21, 23, 59)]) {
        final bs = NepaliCalendarService.toNepali(d);
        expect([bs.year, bs.month, bs.day], [2083, 6, 5], reason: '$d');
      }
    });

    test('every Baisakh 1 in the supported range converts to day 1 of month 1', () {
      for (var y = 2001; y <= 2098; y++) {
        final ad = NepaliCalendarService.toGregorian(NepaliDateTime(y, 1, 1));
        final bs = NepaliCalendarService.toNepali(ad);
        expect([bs.year, bs.month, bs.day], [y, 1, 1], reason: 'BS $y');
      }
    });

    test('a time of day never shifts the converted date', () {
      final morning = NepaliCalendarService.toNepali(DateTime(2026, 9, 18, 0, 5));
      final night = NepaliCalendarService.toNepali(DateTime(2026, 9, 18, 23, 55));
      expect([morning.year, morning.month, morning.day], [night.year, night.month, night.day]);
    });

    test('format renders month names for a known date', () {
      expect(NepaliCalendarService.format(DateTime(2026, 4, 14), 'dd MMMM yyyy'), '01 Baishakh 2083');
    });
  });
}
