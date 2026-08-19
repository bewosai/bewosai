import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/excel_import_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/excel_import_widgets.dart';
import '../providers/inventory_provider.dart';

const _kTemplateHeaders = [
  'name',
  'sale_price',
  'purchase_price',
  'stock_quantity',
  'low_stock_threshold',
  'barcode',
  'description',
];

/// Products bulk-import via Excel — mirrors the web app's ImportPage but as
/// a native on-device pick + parse + preview + confirm flow, since there's
/// no browser file input here. Gated the same way the backend enforces it
/// (Premium plan, "excel_import" feature switch).
class InventoryImportScreen extends StatefulWidget {
  const InventoryImportScreen({super.key});

  @override
  State<InventoryImportScreen> createState() => _InventoryImportScreenState();
}

class _InventoryImportScreenState extends State<InventoryImportScreen> {
  bool _generatingTemplate = false;
  bool _picking = false;
  bool _importing = false;
  String? _fileName;
  List<Map<String, dynamic>>? _rows;
  List<String> _validationErrors = [];
  Map<String, dynamic>? _result;

  Future<void> _downloadTemplate() async {
    setState(() => _generatingTemplate = true);
    try {
      final path = await ExcelImportUtils.writeTemplate(
        sheetName: 'Products',
        headers: _kTemplateHeaders,
        exampleRow: const ['Coca Cola 500ml', '60', '45', '100', '10', '12345678', 'Cold drink'],
        fileName: 'bewosai_products_template.xlsx',
      );
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Bewosai product import template'));
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not create the template file', isError: true);
    } finally {
      if (mounted) setState(() => _generatingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _validationErrors = [];
      _rows = null;
      _result = null;
    });

    final picked = await ExcelImportUtils.pickAndParse();
    if (picked == null) return;
    if (picked.error != null) {
      if (mounted) showAppSnackBar(context, picked.error!, isError: true);
      return;
    }

    setState(() => _picking = true);
    final rows = <Map<String, dynamic>>[];
    final errors = <String>[];
    var rowNum = 1;
    for (final map in picked.rows) {
      rowNum++;
      final name = map['name'] ?? '';
      if (name.isEmpty) {
        errors.add('Row $rowNum: "name" is required');
        continue;
      }
      final rawSalePrice = map['sale_price'] ?? '';
      if (rawSalePrice.isNotEmpty && double.tryParse(rawSalePrice) == null) {
        errors.add('Row $rowNum: sale_price must be a number');
      }
      rows.add({
        'name': name,
        'sale_price': double.tryParse(rawSalePrice) ?? 0,
        'purchase_price': double.tryParse(map['purchase_price'] ?? '') ?? 0,
        'stock_quantity': double.tryParse(map['stock_quantity'] ?? '') ?? 0,
        'low_stock_threshold': double.tryParse(map['low_stock_threshold'] ?? '') ?? 5,
        'barcode': map['barcode'] ?? '',
        'description': map['description'] ?? '',
      });
    }
    if (rows.length > ExcelImportUtils.maxEntries) {
      errors.add('Only up to ${ExcelImportUtils.maxEntries} rows are supported (found ${rows.length})');
    }

    if (!mounted) return;
    setState(() {
      _fileName = picked.fileName;
      _rows = rows;
      _validationErrors = errors;
      _picking = false;
    });
  }

  Future<void> _confirmImport() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty || _validationErrors.isNotEmpty) return;
    setState(() => _importing = true);
    final provider = context.read<InventoryProvider>();
    final result = await provider.bulkImportProducts(rows);
    if (!mounted) return;
    setState(() {
      _importing = false;
      if (result != null) {
        _result = result;
        _rows = null;
        _fileName = null;
      }
    });
    if (result == null) {
      showAppSnackBar(context, provider.error ?? 'Import failed. Please try again.', isError: true);
    }
  }

  void _reset() {
    setState(() {
      _rows = null;
      _fileName = null;
      _validationErrors = [];
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: 'excel_import',
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Products')),
        body: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_result != null)
                ImportResultCard(
                  result: _result!,
                  itemLabelSingular: 'product',
                  itemLabelPlural: 'products',
                  onImportMore: _reset,
                )
              else if (_rows != null)
                ImportPreviewSection(
                  fileName: _fileName ?? '',
                  rowCount: _rows!.length,
                  errors: _validationErrors,
                  previewRows: [
                    for (final r in _rows!) ImportPreviewRow(r['name'] as String, 'Rs. ${r['sale_price']}'),
                  ],
                  importing: _importing,
                  confirmLabel: 'Confirm & Import ${_rows!.length} Products',
                  onClear: _reset,
                  onConfirm: _confirmImport,
                )
              else ...[
                const ImportStepsCard(
                  title: 'Import Products in 3 Steps',
                  steps: [
                    ImportStep('Download & Fill the Template', 'Get the sample Excel file and add your products in the same columns.'),
                    ImportStep('Select Your File', "Pick the completed spreadsheet — you'll get a preview before anything is saved."),
                    ImportStep('Review & Confirm', 'Fix any flagged rows, then confirm to add everything to your inventory at once.'),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _generatingTemplate ? null : _downloadTemplate,
                    icon: _generatingTemplate
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Get Sample File'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Only Excel files up to ${ExcelImportUtils.maxEntries} entries & 1MB are supported.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Select a File',
                  icon: Icons.upload_file_outlined,
                  isLoading: _picking,
                  onPressed: _pickFile,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
