import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_widgets.dart';

/// Shared building blocks for the "pick Excel → preview → confirm" bulk
/// import flow, reused by both the products and parties import screens
/// (and any future entity that gets bulk import) so each one only has to
/// supply its own field mapping and validation, not its own UI.

class ImportStep {
  final String title;
  final String description;
  const ImportStep(this.title, this.description);
}

class ImportStepsCard extends StatelessWidget {
  final String title;
  final List<ImportStep> steps;
  const ImportStepsCard({super.key, required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepRow(number: i + 1, step: steps[i]),
          if (i != steps.length - 1) const _StepConnector(),
        ],
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 2, color: AppColors.divider)),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final ImportStep step;
  const _StepRow({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(step.description, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in the preview table — [primary] is the bold left-aligned label
/// (usually the name), [secondary] the lighter right-aligned value.
class ImportPreviewRow {
  final String primary;
  final String secondary;
  const ImportPreviewRow(this.primary, this.secondary);
}

class ImportPreviewSection extends StatelessWidget {
  final String fileName;
  final int rowCount;
  final List<String> errors;
  final List<ImportPreviewRow> previewRows;
  final bool importing;
  final String confirmLabel;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  const ImportPreviewSection({
    super.key,
    required this.fileName,
    required this.rowCount,
    required this.errors,
    required this.previewRows,
    required this.importing,
    required this.confirmLabel,
    required this.onClear,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = errors.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 4),
            Text('$rowCount row${rowCount == 1 ? '' : 's'} found', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        if (hasErrors) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      '${errors.length} issue${errors.length == 1 ? '' : 's'} to fix',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in errors.take(8))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('•  $e', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                if (errors.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('…and ${errors.length - 8} more', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        AppSectionCard(
          title: 'Preview',
          children: [
            for (final r in previewRows.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.primary,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text(r.secondary, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            if (previewRows.length > 10)
              Text('…and ${previewRows.length - 10} more rows', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: hasErrors ? 'Fix issues to continue' : confirmLabel,
          icon: Icons.check_circle_outline,
          isLoading: importing,
          onPressed: hasErrors ? null : onConfirm,
        ),
      ],
    );
  }
}

class ImportResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String itemLabelSingular;
  final String itemLabelPlural;
  final VoidCallback onImportMore;

  const ImportResultCard({
    super.key,
    required this.result,
    required this.itemLabelSingular,
    required this.itemLabelPlural,
    required this.onImportMore,
  });

  @override
  Widget build(BuildContext context) {
    final created = result['created'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final skippedDetails = (result['skipped_details'] as List?) ?? [];
    final label = created == 1 ? itemLabelSingular : itemLabelPlural;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 40),
              const SizedBox(height: 12),
              const Text('Import Successful', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.success)),
              const SizedBox(height: 6),
              Text(
                '$created $label added${skipped > 0 ? ' · $skipped row${skipped == 1 ? '' : 's'} skipped' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.success),
              ),
            ],
          ),
        ),
        if (skippedDetails.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppSectionCard(
            title: 'Skipped rows',
            children: [
              for (final s in skippedDetails.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('•  ${(s as Map)['reason'] ?? 'Unknown error'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Import More', icon: Icons.upload_file_outlined, onPressed: onImportMore),
      ],
    );
  }
}
