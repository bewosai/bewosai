import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:bewosai_app/core/calendar/bs_calendar_table.dart';
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

  group('Bikram Sambat calendar — the whole supported range', () {
    // Published Baishakh 1 dates (Hamro Patro): the years the nepali_utils table
    // gets wrong from 2085 on, so these guard the table we use instead.
    final publishedNewYears = <int, DateTime>{
      2060: DateTime(2003, 4, 14),
      2070: DateTime(2013, 4, 14),
      2073: DateTime(2016, 4, 13),
      2084: DateTime(2027, 4, 14),
      2085: DateTime(2028, 4, 13),
      2086: DateTime(2029, 4, 14),
      2087: DateTime(2030, 4, 14),
    };
    publishedNewYears.forEach((bsYear, ad) {
      test('Baishakh 1, $bsYear is ${ad.toIso8601String().substring(0, 10)}', () {
        final bs = NepaliCalendarService.toNepali(ad);
        expect([bs.year, bs.month, bs.day], [bsYear, 1, 1]);
        expect(NepaliCalendarService.toGregorian(NepaliDateTime(bsYear, 1, 1)), ad);
      });
    });

    test('every day from BS 2000-01-01 to 2099-12-end converts and comes straight back', () {
      var day = DateTime(1943, 4, 14);
      final end = DateTime(2043, 4, 13);
      var prev = NepaliCalendarService.toNepali(day);
      expect([prev.year, prev.month, prev.day], [2000, 1, 1]);
      var count = 1;
      while (day.isBefore(end)) {
        day = DateTime(day.year, day.month, day.day + 1);
        final cur = NepaliCalendarService.toNepali(day);
        // exactly one BS day forward each time (or the first of the next month/year)
        if (cur.month == prev.month && cur.year == prev.year) {
          expect(cur.day, prev.day + 1, reason: '$day');
        } else {
          expect(cur.day, 1, reason: '$day');
          expect(prev.day, NepaliCalendarService.daysInMonth(prev.year, prev.month), reason: '$day');
        }
        expect(NepaliCalendarService.toGregorian(cur), day, reason: 'round trip $day');
        prev = cur;
        count++;
      }
      expect([prev.year, prev.month, prev.day], [2099, 12, NepaliCalendarService.daysInMonth(2099, 12)]);
      expect(count, 36525);
    });

    test('agrees with the package BS->AD for every day through BS 2083 (independent check)', () {
      // The package's BS->AD is calendar arithmetic and matches the published dates up to
      // 2083; our table must reproduce it exactly there (they only part ways from 2084).
      for (var y = 2000; y <= 2083; y++) {
        for (var m = 1; m <= 12; m++) {
          for (var d = 1; d <= NepaliCalendarService.daysInMonth(y, m); d++) {
            final ours = NepaliCalendarService.toGregorian(NepaliDateTime(y, m, d));
            final theirs = NepaliDateTime(y, m, d).toDateTime();
            expect(
              DateTime(ours.year, ours.month, ours.day),
              DateTime(theirs.year, theirs.month, theirs.day),
              reason: 'BS $y-$m-$d',
            );
          }
        }
      }
    });

    test('the table itself is sane: 29-32 days a month, 363-366 a year', () {
      expect(bsMonthDays.keys.toList()..sort(), [for (var y = 2000; y <= 2099; y++) y]);
      bsMonthDays.forEach((year, months) {
        expect(months.length, 12, reason: '$year');
        for (final days in months) {
          expect(days, inInclusiveRange(29, 32), reason: '$year');
        }
        expect(months.fold<int>(0, (a, b) => a + b), inInclusiveRange(363, 366), reason: '$year');
      });
    });

    test('the month grid starts on the right weekday', () {
      // Ashwin 1, 2083 = Thu 17 Sep 2026; Baishakh 1, 2083 = Tue 14 Apr 2026. Sun=1..Sat=7.
      expect(NepaliCalendarService.firstWeekday(2083, 6), 5);
      expect(NepaliCalendarService.firstWeekday(2083, 1), 3);
    });

    test('dates outside the supported range throw a clear RangeError, not a wrong date', () {
      expect(() => NepaliCalendarService.toNepali(DateTime(1943, 4, 13)), throwsRangeError);
      expect(() => NepaliCalendarService.toNepali(DateTime(2043, 4, 14)), throwsRangeError);
      expect(() => NepaliCalendarService.daysInMonth(1999, 1), throwsRangeError);
    });

    test('is identical to the website table (client/src/utils/nepaliDate.js)', () {
      final file = File('../client/src/utils/nepaliDate.js');
      if (!file.existsSync()) {
        markTestSkipped('website source not next to the app in this checkout');
        return;
      }
      final web = <int, List<int>>{
        for (final m in RegExp(r'^\s*(\d{4}): \[([\d, ]+)\]', multiLine: true).allMatches(file.readAsStringSync()))
          int.parse(m.group(1)!): m.group(2)!.split(',').map((e) => int.parse(e.trim())).toList(),
      };
      expect(web.keys.toList()..sort(), [for (var y = 2000; y <= 2099; y++) y],
          reason: 'the website must list every BS year 2000-2099');
      web.forEach((year, months) => expect(months, bsMonthDays[year], reason: 'BS $year differs between web and app'));
    });
  });
}
