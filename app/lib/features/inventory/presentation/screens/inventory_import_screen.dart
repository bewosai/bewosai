import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/bulk_import_screen.dart';
import '../providers/inventory_provider.dart';

/// Products bulk import from Excel — the shared BulkImportScreen flow (server
/// checks every row, preview filtered Ready / Will skip, import the ready ones).
/// Same columns as the website's template and the products export.
class InventoryImportScreen extends StatelessWidget {
  const InventoryImportScreen({super.key});

  static final config = BulkImportConfig(
    title: 'Import Products',
    noun: 'product',
    nounPlural: 'products',
    endpoint: '/inventory/products/bulk-import/',
    payloadKey: 'products',
    module: 'inventory',
    templateHeaders: const [
      'name', 'category', 'unit', 'sale_price', 'purchase_price',
      'secondary_sale_price', 'secondary_purchase_price',
      'stock_quantity', 'low_stock_threshold', 'barcode', 'hs_code', 'description',
    ],
    // secondary_* = own price per secondary unit (e.g. per Piece of a Box);
    // leave blank to use price ÷ conversion.
    templateExamples: const [
      ['Coca Cola 500ml', 'Beverages', 'Piece', '60', '45', '', '', '100', '10', '12345678', '22021010', 'Cold drink'],
      ['Biscuit Box', 'Snacks', 'Box', '1200', '1000', '110', '90', '20', '5', '', '', 'Box of 12'],
    ],
    detailColumn: 'sale_price',
    detailLabel: 'Sale price',
    onImported: (context) => context.read<InventoryProvider>().load(),
  );

  @override
  Widget build(BuildContext context) => BulkImportScreen(config: config);
}
