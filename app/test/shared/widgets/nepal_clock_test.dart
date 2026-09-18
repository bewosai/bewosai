import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/core/utils/formatters.dart';
import 'package:bewosai_app/shared/widgets/nepal_clock.dart';

void main() {
  tearDown(() => Formatters.useNepaliCalendar = false);

  testWidgets('shows the date and the time labelled as Nepal time', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NepalClock())));
    expect(find.textContaining('NPT'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
  });

  testWidgets('follows the calendar choice: Bikram Sambat months when it is on', (tester) async {
    Formatters.useNepaliCalendar = true;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NepalClock())));
    // A BS date is in the 2000s (2083 etc.), an AD one is not.
    final text = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
    expect(RegExp(r'20[7-9]\d').hasMatch(text), isTrue, reason: text);
  });
}
