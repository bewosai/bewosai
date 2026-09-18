import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/shared/widgets/return_lines.dart';

void main() {
  group('plainNumber', () {
    test('has no thousands separator, so it can be read back', () {
      expect(plainNumber(1000), '1000');
      expect(double.parse(plainNumber(12500)), 12500);
    });
    test('keeps decimals, drops a trailing .0', () {
      expect(plainNumber(2.5), '2.5');
      expect(plainNumber(3.0), '3');
    });
  });

  group('ReturnLine', () {
    test('a discounted line refunds what was actually paid, not the list price', () {
      // 3 units listed at 100 but the line total was 270 after a 30 discount.
      final price = ReturnLine.effectivePrice(quantity: 3, unitPrice: 100, total: 270);
      expect(price, 90);
    });

    test('unit price is rounded to paisa (the backend stores two decimals)', () {
      expect(ReturnLine.effectivePrice(quantity: 3, unitPrice: 100, total: 100), 33.33);
    });

    test('falls back to the unit price when there is no line total', () {
      expect(ReturnLine.effectivePrice(quantity: 2, unitPrice: 50, total: 0), 50);
    });

    test('amount and totalOf multiply and round', () {
      final a = ReturnLine(productName: 'A', maxQuantity: 10, unitPrice: 33.33)..qtyController.text = '3';
      final b = ReturnLine(productName: 'B', maxQuantity: 10, unitPrice: 10)..qtyController.text = '1.5';
      expect(a.amount, closeTo(99.99, 1e-9));
      expect(ReturnLine.totalOf([a, b]), 114.99);
      a.dispose();
      b.dispose();
    });

    test('an empty or invalid quantity counts as zero', () {
      final l = ReturnLine(productName: 'A', maxQuantity: 5, unitPrice: 10);
      expect(l.qty, 0);
      l.qtyController.text = 'abc';
      expect(l.qty, 0);
      l.dispose();
    });
  });

  group('ReturnLineRow', () {
    Future<ReturnLine> pump(WidgetTester tester, {required double max}) async {
      final line = ReturnLine(productName: 'Rice', maxQuantity: max, unitPrice: 120, unitLabel: 'Kg');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReturnLineRow(line: line, billedLabel: 'Sold', onChanged: () {}),
        ),
      ));
      return line;
    }

    testWidgets('a quantity of 1,000 or more is kept, not read back as 0', (tester) async {
      final line = await pump(tester, max: 5000);
      await tester.enterText(find.byType(TextField), '2500');
      expect(line.qtyController.text, '2500');
      expect(line.qty, 2500);
    });

    testWidgets('typing more than is left clamps to what is left', (tester) async {
      final line = await pump(tester, max: 1500);
      await tester.enterText(find.byType(TextField), '9999');
      expect(line.qtyController.text, '1500');
      expect(line.qty, 1500);
    });

    testWidgets('"Return all" fills in everything that is left', (tester) async {
      final line = await pump(tester, max: 4.5);
      await tester.tap(find.byTooltip('Return all'));
      await tester.pump();
      expect(line.qty, 4.5);
    });

    testWidgets('a fully returned line is locked and says so', (tester) async {
      await pump(tester, max: 0);
      expect(find.text('Already fully returned'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('shows how much can still be returned', (tester) async {
      await pump(tester, max: 7);
      expect(find.textContaining('up to 7 Kg'), findsOneWidget);
    });
  });
}
