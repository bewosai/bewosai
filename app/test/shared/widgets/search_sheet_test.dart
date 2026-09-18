import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/shared/widgets/app_widgets.dart';

void main() {
  // Regression: SearchSheet used to call onSelected and THEN pop. When
  // onSelected opens a follow-up sheet (the invoice's item-detail sheet), the
  // pop closed that new sheet instead of the picker, leaving the picker open
  // and the detail sheet gone.
  testWidgets('picking an item closes the picker and leaves the follow-up sheet open', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SearchSheet<String>(
                  title: 'Select Product',
                  items: const ['Rice', 'Sugar'],
                  labelBuilder: (s) => s,
                  subtitleBuilder: (s) => 'sub $s',
                  onSelected: (s) => showModalBottomSheet(
                    context: context,
                    builder: (_) => SizedBox(height: 200, child: Text('detail for $s')),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Select Product'), findsOneWidget);

    await tester.tap(find.text('Sugar'));
    await tester.pumpAndSettle();

    expect(find.text('detail for Sugar'), findsOneWidget);
    expect(find.text('Select Product'), findsNothing);
  });
}
