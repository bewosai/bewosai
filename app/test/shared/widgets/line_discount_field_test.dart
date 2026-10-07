import 'package:bewosai_app/shared/widgets/line_discount_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({TextEditingController controller, List<bool> modes})> pump(
    WidgetTester tester, {
    required bool isPercent,
    required String text,
    double gross = 400,
  }) async {
    final controller = TextEditingController(text: text);
    final modes = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineDiscountField(
          controller: controller,
          isPercent: isPercent,
          gross: gross,
          onModeChanged: modes.add,
          onChanged: () {},
        ),
      ),
    ));
    return (controller: controller, modes: modes);
  }

  testWidgets('both choices are shown as labelled options', (tester) async {
    await pump(tester, isPercent: false, text: '50');
    expect(find.text('Discount as'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Amount (Rs)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '% of line'), findsOneWidget);
  });

  testWidgets('choosing % converts Rs 50 of a Rs 400 line to 12.5%', (tester) async {
    final f = await pump(tester, isPercent: false, text: '50');
    await tester.tap(find.widgetWithText(ChoiceChip, '% of line'));
    expect(f.modes, [true]);
    expect(f.controller.text, '12.50');
  });

  testWidgets('choosing Rs converts 10% of a Rs 400 line to Rs 40', (tester) async {
    final f = await pump(tester, isPercent: true, text: '10');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Amount (Rs)'));
    expect(f.modes, [false]);
    expect(f.controller.text, '40');
  });

  testWidgets('tapping the option already chosen changes nothing', (tester) async {
    final f = await pump(tester, isPercent: false, text: '50');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Amount (Rs)'));
    expect(f.modes, isEmpty);
    expect(f.controller.text, '50');
  });
}
