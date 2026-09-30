import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/excel_import_utils.dart';
import 'app_widgets.dart';
import 'excel_import_widgets.dart';

/// What differs between the product and party imports.
class BulkImportConfig {
  final String title; // "Import Products"
  final String noun; // "product"
  final String nounPlural; // "products"
  final String endpoint; // '/inventory/products/bulk-import/'
  final String payloadKey; // 'products'
  final String module; // staff permission module for FeatureGate
  final List<String> templateHeaders;
  final List<List<String>> templateExamples;
  /// Column shown under each row's name in the preview (e.g. sale_price).
  final String detailColumn;
  final String detailLabel;
  /// Reloads the matching list once rows were created.
  final Future<void> Function(BuildContext context) onImported;

  const BulkImportConfig({
    required this.title,
    required this.noun,
    required this.nounPlural,
    required this.endpoint,
    required this.payloadKey,
    required this.module,
    required this.templateHeaders,
    required this.templateExamples,
    required this.detailColumn,
    required this.detailLabel,
    required this.onImported,
  });
}

/// Excel bulk import, the same flow as the website's Import page: pick a file →
/// the server checks every row against the business's real data without saving
/// (dry run) → preview filtered All / Ready / Will skip with each skipped row's
/// reason → import the ready rows; the rest are skipped, never the whole file.
/// Values are sent exactly as typed ("1,200" included) — the server reads them.
class BulkImportScreen extends StatefulWidget {
  final BulkImportConfig config;
  const BulkImportScreen({super.key, required this.config});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

enum _Filter { all, ready, skipped }

class _BulkImportScreenState extends State<BulkImportScreen> {
  BulkImportConfig get c => widget.config;

  bool _generatingTemplate = false;
  bool _checking = false;
  bool _importing = false;
  String? _fileName;
  List<Map<String, String>>? _rows;
  List<Map<String, dynamic>>? _checks; // one per row, same order
  _Filter _filter = _Filter.all;
  Map<String, dynamic>? _result;

  Future<Map<String, dynamic>> _send(List<Map<String, String>> rows, {required bool dryRun}) async {
    try {
      final res = await ApiClient.instance.dio.post(c.endpoint, data: {c.payloadKey: rows, 'dry_run': dryRun});
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _generatingTemplate = true);
    try {
      final path = await ExcelImportUtils.writeRows(
        sheetName: c.title.replaceFirst('Import ', ''),
        headers: c.templateHeaders,
        rows: c.templateExamples,
        fileName: 'bewosai_${c.nounPlural}_template.xlsx',
      );
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Bewosai ${c.noun} import template'));
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not create the template file', isError: true);
    } finally {
      if (mounted) setState(() => _generatingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    final picked = await ExcelImportUtils.pickAndParse();
    if (picked == null || !mounted) return;
    if (picked.error != null) {
      showAppSnackBar(context, picked.error!, isError: true);
      return;
    }
    if (picked.rows.isEmpty) {
      showAppSnackBar(context, 'This file has no rows under the header', isError: true);
      return;
    }
    if (picked.rows.length > ExcelImportUtils.maxEntries) {
      showAppSnackBar(context,
          'Only up to ${ExcelImportUtils.maxEntries} rows at a time (this file has ${picked.rows.length}). Split it into smaller files.',
          isError: true);
      return;
    }
    setState(() {
      _result = null;
      _fileName = picked.fileName;
      _rows = picked.rows;
      _checks = null;
      _filter = _Filter.all;
      _checking = true;
    });
    try {
      final data = await _send(picked.rows, dryRun: true);
      if (!mounted) return;
      setState(() => _checks = [for (final r in (data['results'] as List? ?? [])) Map<String, dynamic>.from(r as Map)]);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e is ApiException ? e.message : "Couldn't check the file", isError: true);
      _reset();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  int get _readyCount => _checks?.where((r) => r['status'] == 'ready').length ?? 0;

  Future<void> _confirmImport() async {
    final rows = _rows;
    if (rows == null || _readyCount == 0) return;
    setState(() => _importing = true);
    try {
      final data = await _send(rows, dryRun: false);
      if (!mounted) return;
      setState(() {
        _result = data;
        _rows = null;
        _checks = null;
        _fileName = null;
      });
      await c.onImported(context);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e is ApiException ? e.message : 'Import failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() => setState(() {
        _rows = null;
        _checks = null;
        _fileName = null;
        _result = null;
        _filter = _Filter.all;
      });

  // Every skipped row back out as .xlsx (its columns + why) to fix and re-upload.
  Future<void> _downloadSkippedRows() async {
    final details = (_result?['skipped_details'] as List?) ?? [];
    if (details.isEmpty) return;
    final columns = <String>{};
    for (final d in details) {
      final row = (d as Map)['row'] as Map?;
      if (row != null) columns.addAll(row.keys.map((k) => k.toString()));
    }
    try {
      final path = await ExcelImportUtils.writeRows(
        sheetName: 'Skipped rows',
        headers: ['excel_row', ...columns, 'reason'],
        rows: [
          for (final d in details.cast<Map>())
            [
              '${d['excel_row'] ?? ''}',
              for (final col in columns) (d['row'] as Map?)?[col]?.toString() ?? '',
              d['reason']?.toString() ?? '',
            ],
        ],
        fileName: '${c.nounPlural}_import_skipped_rows.xlsx',
      );
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Skipped ${c.noun} import rows'));
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not create the file', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: 'excel_import',
      module: c.module,
      action: 'create',
      child: Scaffold(
        appBar: AppBar(title: Text(c.title), actions: const [HomeLogoButton()]),
        body: ResponsiveBody(
          child: _result != null
              ? ListView(padding: const EdgeInsets.all(16), children: [
                  ImportResultCard(
                    result: _result!,
                    itemLabelSingular: c.noun,
                    itemLabelPlural: c.nounPlural,
                    onImportMore: _reset,
                    onDownloadFailedRows:
                        ((_result!['skipped_details'] as List?)?.isNotEmpty ?? false) ? _downloadSkippedRows : null,
                  ),
                ])
              : _rows != null
                  ? _buildPreview()
                  : _buildStart(),
        ),
      ),
    );
  }

  Widget _buildStart() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImportStepsCard(
            title: '${c.title} in 3 Steps',
            steps: [
              ImportStep('Download & Fill the Template', 'Get the sample Excel file and add your ${c.nounPlural} in the same columns.'),
              ImportStep('Select Your File', 'Every row is checked first — nothing is saved until you confirm.'),
              ImportStep('Review & Import', 'See which rows are ready and why any will be skipped, then import the ready ones.'),
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
          PrimaryButton(label: 'Select a File', icon: Icons.upload_file_outlined, isLoading: _checking, onPressed: _pickFile),
        ],
      );

  Widget _buildPreview() {
    final checks = _checks;
    if (_checking || checks == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.orange),
          SizedBox(height: 12),
          Text('Checking every row…'),
        ]),
      );
    }
    final rows = _rows!;
    final ready = _readyCount;
    final skipped = checks.length - ready;
    final visible = [
      for (var i = 0; i < rows.length && i < checks.length; i++)
        if (_filter == _Filter.all ||
            (_filter == _Filter.ready && checks[i]['status'] == 'ready') ||
            (_filter == _Filter.skipped && checks[i]['status'] != 'ready'))
          (row: rows[i], check: checks[i]),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: Text(_fileName ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(onPressed: _reset, icon: const Icon(Icons.close, size: 16), label: const Text('Clear')),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (filter, label) in [
              (_Filter.all, 'All (${checks.length})'),
              (_Filter.ready, 'Ready ($ready)'),
              (_Filter.skipped, 'Will skip ($skipped)'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text('No rows here', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final (:row, :check) = visible[i];
                    final isReady = check['status'] == 'ready';
                    final name = (row['name'] ?? '').isEmpty ? '(no name)' : row['name']!;
                    final detail = row[c.detailColumn] ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: (isReady ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                        child: Icon(isReady ? Icons.check : Icons.block, size: 16, color: isReady ? AppColors.success : AppColors.error),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        isReady
                            ? 'Row ${check['row']}${detail.isEmpty ? '' : ' · ${c.detailLabel}: $detail'}'
                            : 'Row ${check['row']} · ${check['reason'] ?? 'Will be skipped'}',
                        style: TextStyle(color: isReady ? AppColors.textSecondary : AppColors.error, fontSize: 12.5),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                ready == 0
                    ? 'No rows are ready — fix the file and select it again.'
                    : '$ready ready${skipped > 0 ? ', $skipped will be skipped' : ''}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: ready == 1 ? 'Import 1 ready ${c.noun}' : 'Import $ready ready ${c.nounPlural}',
                isLoading: _importing,
                onPressed: ready == 0 ? null : _confirmImport,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
