import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/core/calendar/nepal_time.dart';
import 'package:bewosai_app/core/utils/formatters.dart';

void main() {
  tearDown(() => Formatters.useNepaliCalendar = false);

  group('NepalTime.fromInstant', () {
    test('is UTC+5:45', () {
      final n = NepalTime.fromInstant(DateTime.utc(2026, 9, 18, 0, 0));
      expect([n.hour, n.minute], [5, 45]);
    });

    test('crosses midnight before UTC does', () {
      // 20:00 UTC on the 17th is already 01:45 on the 18th in Nepal.
      final n = NepalTime.fromInstant(DateTime.utc(2026, 9, 17, 20, 0));
      expect([n.year, n.month, n.day, n.hour, n.minute], [2026, 9, 18, 1, 45]);
    });

    test('rolls over month and year', () {
      final month = NepalTime.fromInstant(DateTime.utc(2026, 9, 30, 20, 0));
      expect([month.month, month.day], [10, 1]);
      final year = NepalTime.fromInstant(DateTime.utc(2026, 12, 31, 20, 0));
      expect([year.year, year.month, year.day], [2027, 1, 1]);
    });

    test('gives the same answer whatever timezone the input is expressed in', () {
      final utc = DateTime.utc(2026, 9, 17, 20, 0);
      final local = utc.toLocal();
      expect(NepalTime.fromInstant(local), NepalTime.fromInstant(utc));
    });

    test('is a plain (non-UTC) wall-clock value', () {
      expect(NepalTime.fromInstant(DateTime.utc(2026, 1, 1)).isUtc, isFalse);
      expect(NepalTime.now().isUtc, isFalse);
    });
  });

  group('Formatters follow the Nepal calendar for server timestamps', () {
    test('a UTC moment that is already the next day in Nepal shows the Nepal date', () {
      expect(Formatters.date(DateTime.utc(2026, 9, 17, 20, 0)), '18 Sep 2026');
      expect(Formatters.dateShort(DateTime.utc(2026, 9, 17, 20, 0)), '18 Sep');
    });

    test('a date-only value is shown as entered, never shifted', () {
      expect(Formatters.date(DateTime(2026, 9, 18)), '18 Sep 2026');
    });

    test('the Bikram Sambat display uses the Nepal date too', () {
      Formatters.useNepaliCalendar = true;
      // 18 Sep 2026 (Nepal) = 2 Ashwin 2083 (short month style: Ash)
      expect(Formatters.date(DateTime.utc(2026, 9, 17, 20, 0)), '02 Ash 2083');
    });
  });
}
