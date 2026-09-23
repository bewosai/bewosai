import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/excel_import_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/excel_import_widgets.dart';
import '../providers/party_provider.dart';

const _kTemplateHeaders = ['name', 'party_type', 'phone', 'email', 'address', 'opening_balance'];
const _kValidTypes = ['CUSTOMER', 'SUPPLIER', 'BOTH'];

/// Parties bulk-import via Excel — same flow as [InventoryImportScreen],
/// built on the shared pick/parse/preview widgets so only the field
/// mapping and validation differ between the two.
class PartyImportScreen extends StatefulWidget {
  const PartyImportScreen({super.key});

  @override
  State<PartyImportScreen> createState() => _PartyImportScreenState();
}

class _PartyImportScreenState extends State<PartyImportScreen> {
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
        sheetName: 'Parties',
        headers: _kTemplateHeaders,
        exampleRow: const ['Ram Prasad', 'CUSTOMER', '9841000001', 'ram@example.com', 'Kathmandu', '0'],
        fileName: 'bewosai_parties_template.xlsx',
      );
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Bewosai party import template'));
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
      var partyType = (map['party_type'] ?? '').toUpperCase();
      if (partyType.isNotEmpty && !_kValidTypes.contains(partyType)) {
        errors.add('Row $rowNum: party_type must be CUSTOMER, SUPPLIER, or BOTH');
      }
      if (!_kValidTypes.contains(partyType)) partyType = 'CUSTOMER';

      final rawBalance = map['opening_balance'] ?? '';
      if (rawBalance.isNotEmpty && double.tryParse(rawBalance) == null) {
        errors.add('Row $rowNum: opening_balance must be a number');
      }
      rows.add({
        'name': name,
        'party_type': partyType,
        'phone': map['phone'] ?? '',
        'email': map['email'] ?? '',
        'address': map['address'] ?? '',
        'opening_balance': double.tryParse(rawBalance) ?? 0,
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
    final provider = context.read<PartyProvider>();
    final result = await provider.bulkImportParties(rows);
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

  // Writes every skipped row back out as .xlsx (original columns + why it
  // was skipped) so the user can fix just those rows and re-upload,
  // instead of re-checking a whole spreadsheet by hand.
  Future<void> _downloadFailedRows() async {
    final details = (_result?['skipped_details'] as List?) ?? [];
    if (details.isEmpty) return;
    final columns = <String>{};
    for (final d in details) {
      final row = (d as Map)['row'] as Map?;
      if (row != null) columns.addAll(row.keys.map((k) => k.toString()));
    }
    final headers = [...columns, 'reason'];
    try {
      final path = await ExcelImportUtils.writeRows(
        sheetName: 'Failed rows',
        headers: headers,
        rows: [
          for (final d in details)
            [
              for (final c in columns) ((d as Map)['row'] as Map?)?[c]?.toString() ?? '',
              (d as Map)['reason']?.toString() ?? '',
            ],
        ],
        fileName: 'parties_import_failed_rows.xlsx',
      );
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Failed party import rows'));
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not create the file', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: 'excel_import',
      module: 'parties',
      action: 'create',
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Parties'), actions: const [HomeLogoButton()]),
        body: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_result != null)
                ImportResultCard(
                  result: _result!,
                  itemLabelSingular: 'party',
                  itemLabelPlural: 'parties',
                  onImportMore: _reset,
                  onDownloadFailedRows: ((_result!['skipped_details'] as List?)?.isNotEmpty ?? false)
                      ? _downloadFailedRows
                      : null,
                )
              else if (_rows != null)
                ImportPreviewSection(
                  fileName: _fileName ?? '',
                  rowCount: _rows!.length,
                  errors: _validationErrors,
                  previewRows: [
                    for (final r in _rows!) ImportPreviewRow(r['name'] as String, r['party_type'] as String),
                  ],
                  importing: _importing,
                  confirmLabel: 'Confirm & Import ${_rows!.length} Parties',
                  onClear: _reset,
                  onConfirm: _confirmImport,
                )
              else ...[
                const ImportStepsCard(
                  title: 'Import Parties in 3 Steps',
                  steps: [
                    ImportStep('Download & Fill the Template', 'Get the sample Excel file and add your customers or suppliers in the same columns.'),
                    ImportStep('Select Your File', "Pick the completed spreadsheet — you'll get a preview before anything is saved."),
                    ImportStep('Review & Confirm', 'Fix any flagged rows, then confirm to add everything to your parties list at once.'),
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
