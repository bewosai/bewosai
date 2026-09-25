import 'package:bewosai_app/core/input/zero_field_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _field(TextEditingController c, {TextInputType type = TextInputType.number}) =>
    MaterialApp(home: Scaffold(body: TextField(controller: c, keyboardType: type)));

void main() {
  // setUp, not setUpAll: the test binding swaps in a fresh FocusManager per test.
  setUp(ZeroFieldSelect.install);

  testWidgets('tapping a number box holding 0 selects the 0', (tester) async {
    final c = TextEditingController(text: '0');
    await tester.pumpWidget(_field(c));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 1));
  });

  testWidgets('0.00 in a decimal box is selected too', (tester) async {
    final c = TextEditingController(text: '0.00');
    await tester.pumpWidget(_field(c, type: const TextInputType.numberWithOptions(decimal: true)));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
  });

  testWidgets('a real amount is left alone', (tester) async {
    final c = TextEditingController(text: '250');
    await tester.pumpWidget(_field(c));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(c.selection.isCollapsed, isTrue);
  });

  testWidgets('a text box holding 0 is left alone', (tester) async {
    final c = TextEditingController(text: '0');
    await tester.pumpWidget(_field(c, type: TextInputType.text));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(c.selection.isCollapsed, isTrue);
  });
}
