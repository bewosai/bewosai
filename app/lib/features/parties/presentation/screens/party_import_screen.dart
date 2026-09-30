import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/bulk_import_screen.dart';
import '../providers/party_provider.dart';

/// Parties (customers / suppliers) bulk import from Excel — the shared
/// BulkImportScreen flow. Same columns as the website's parties template.
class PartyImportScreen extends StatelessWidget {
  const PartyImportScreen({super.key});

  static final config = BulkImportConfig(
    title: 'Import Parties',
    noun: 'party',
    nounPlural: 'parties',
    endpoint: '/parties/bulk-import/',
    payloadKey: 'parties',
    module: 'parties',
    templateHeaders: const ['name', 'party_type', 'phone', 'email', 'address', 'opening_balance'],
    // party_type: CUSTOMER, SUPPLIER or BOTH. opening_balance: positive = they
    // owe you (To Receive), negative = you owe them (To Give).
    templateExamples: const [
      ['Ram Prasad', 'CUSTOMER', '9841000001', 'ram@example.com', 'Kathmandu', '0'],
      ['Shyam Suppliers', 'SUPPLIER', '9841000002', '', 'Pokhara', '-5000'],
    ],
    detailColumn: 'party_type',
    detailLabel: 'Type',
    onImported: (context) => context.read<PartyProvider>().load(),
  );

  @override
  Widget build(BuildContext context) => BulkImportScreen(config: config);
}
