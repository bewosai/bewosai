import 'package:bewosai_app/shared/widgets/excel_import_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These are pure presentational widgets with no Provider/network
/// dependency, which is exactly why they're the first widget tests in this
/// app — Login/OTP-style screens depend on AuthProvider and real API calls,
/// which need a mocking setup (mocktail/mockito) that isn't in this project
/// yet. Testing them properly is a separate, larger follow-up, not
/// something to fake here with a shallow test that doesn't really check
/// anything.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ImportStepsCard', () {
    testWidgets('renders every step\'s title and description, numbered in order', (tester) async {
      await tester.pumpWidget(wrap(const ImportStepsCard(
        title: 'Import Products in 3 Steps',
        steps: [
          ImportStep('Download & Fill the Template', 'Get the sample file.'),
          ImportStep('Select Your File', 'Pick the completed spreadsheet.'),
          ImportStep('Review & Confirm', 'Fix flagged rows, then confirm.'),
        ],
      )));

      expect(find.text('Import Products in 3 Steps'), findsOneWidget);
      expect(find.text('Download & Fill the Template'), findsOneWidget);
      expect(find.text('Select Your File'), findsOneWidget);
      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ImportPreviewSection', () {
    testWidgets('shows validation errors and disables confirm when any exist', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(wrap(ImportPreviewSection(
        fileName: 'products.xlsx',
        rowCount: 2,
        errors: const ['Row 3: "name" is required'],
        previewRows: const [ImportPreviewRow('Coca Cola', 'Rs. 60')],
        importing: false,
        confirmLabel: 'Confirm & Import 2 Products',
        onClear: () {},
        onConfirm: () => confirmed = true,
      )));

      expect(find.text('products.xlsx'), findsOneWidget);
      expect(find.text('1 issue to fix'), findsOneWidget);
      expect(find.text('•  Row 3: "name" is required'), findsOneWidget);
      // Button shows the "fix issues" label instead of the real confirm
      // label while errors exist.
      expect(find.text('Fix issues to continue'), findsOneWidget);
      expect(find.text('Confirm & Import 2 Products'), findsNothing);

      await tester.tap(find.text('Fix issues to continue'));
      await tester.pump();
      expect(confirmed, isFalse, reason: 'the button must be disabled while errors exist');
    });

    testWidgets('confirm button works once there are no errors', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(wrap(ImportPreviewSection(
        fileName: 'parties.xlsx',
        rowCount: 1,
        errors: const [],
        previewRows: const [ImportPreviewRow('Ram Prasad', 'CUSTOMER')],
        importing: false,
        confirmLabel: 'Confirm & Import 1 Party',
        onClear: () {},
        onConfirm: () => confirmed = true,
      )));

      expect(find.text('Confirm & Import 1 Party'), findsOneWidget);
      await tester.tap(find.text('Confirm & Import 1 Party'));
      await tester.pump();
      expect(confirmed, isTrue);
    });
  });

  group('ImportResultCard', () {
    testWidgets('shows created/skipped counts and skip reasons', (tester) async {
      await tester.pumpWidget(wrap(ImportResultCard(
        result: const {
          'created': 8,
          'skipped': 2,
          'skipped_details': [
            {'reason': 'Missing name'},
            {'reason': 'Missing name'},
          ],
        },
        itemLabelSingular: 'product',
        itemLabelPlural: 'products',
        onImportMore: () {},
      )));

      expect(find.text('Import Successful'), findsOneWidget);
      expect(find.text('8 products added · 2 rows skipped'), findsOneWidget);
      expect(find.text('•  Missing name'), findsNWidgets(2));
    });

    testWidgets('singular label is used when exactly one item was created', (tester) async {
      await tester.pumpWidget(wrap(ImportResultCard(
        result: const {'created': 1, 'skipped': 0, 'skipped_details': []},
        itemLabelSingular: 'party',
        itemLabelPlural: 'parties',
        onImportMore: () {},
      )));

      expect(find.text('1 party added'), findsOneWidget);
    });
  });
}
