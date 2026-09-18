import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/core/utils/formatters.dart';
import 'package:bewosai_app/shared/widgets/app_date_picker.dart';

Future<DateTime?> _open(
  WidgetTester tester, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
}) async {
  DateTime? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await AppDatePicker.pick(
                context,
                initialDate: initial,
                firstDate: first,
                lastDate: last,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return Future.value(result);
}

void main() {
  setUp(() => Formatters.useNepaliCalendar = true);
  tearDown(() => Formatters.useNepaliCalendar = false);

  testWidgets('shows the Bikram Sambat month for the date being edited', (tester) async {
    await _open(tester, initial: DateTime(2026, 9, 18));
    expect(find.text('Ashwin 2083'), findsOneWidget);
  });

  testWidgets('day 1 sits under the right weekday column', (tester) async {
    // Ashwin 1, 2083 = Thursday 17 Sep 2026.
    await _open(tester, initial: DateTime(2026, 9, 18));
    final thursday = tester.getCenter(find.text('Th')).dx;
    final dayOne = tester.getCenter(find.text('1')).dx;
    expect((dayOne - thursday).abs(), lessThan(2));
  });

  testWidgets('picking a day returns the matching Gregorian date', (tester) async {
    DateTime? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => result = await AppDatePicker.pick(context, initialDate: DateTime(2026, 9, 18)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5')); // Ashwin 5, 2083
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 21));
  });

  testWidgets('cannot page to a month wholly outside the allowed range', (tester) async {
    await _open(
      tester,
      initial: DateTime(2026, 9, 18),
      first: DateTime(2026, 9, 1),
      last: DateTime(2026, 9, 30), // Kartik starts 18 Oct — out of range
    );
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);
    final prev = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left));
    expect(prev.onPressed, isNotNull); // Bhadra still overlaps 1-16 Sep
  });

  testWidgets('paging forward and back across a year end never throws', (tester) async {
    await _open(tester, initial: DateTime(2027, 4, 1)); // Chaitra 2083
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pump();
    }
    expect(find.textContaining('2084'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();
    }
    expect(find.textContaining('2083'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
