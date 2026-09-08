import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/data/models/business_model.dart';
import '../../../auth/data/models/fiscal_year_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsAdvancedScreen extends StatefulWidget {
  const SettingsAdvancedScreen({super.key});

  @override
  State<SettingsAdvancedScreen> createState() => _SettingsAdvancedScreenState();
}

class _SettingsAdvancedScreenState extends State<SettingsAdvancedScreen> {
  // Bumped after a successful fiscal-year close so _ClosedFiscalYearsSection
  // (keyed on this) remounts and refetches instead of showing a stale list.
  int _fiscalYearsRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = auth.currentBusiness;
    final isArchived = business?.status == 'ARCHIVED';

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _dangerTile(
                    context,
                    icon: Icons.event_repeat_outlined,
                    title: 'Close Fiscal Year',
                    description:
                        'Closes the current fiscal year in place — records stay right here, read-only, and stay fully viewable.',
                    onTap: () => _confirmCloseFiscalYear(context, business),
                  ),
                  const Divider(height: 1),
                  _dangerTile(
                    context,
                    icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    title: isArchived ? 'Restore Business Profile' : 'Archive Business Profile',
                    description: isArchived
                        ? 'Restore this business so records can be edited again.'
                        : 'Archive this business and keep its data available in read-only mode.',
                    onTap: () => _confirmArchiveToggle(context, isArchived),
                  ),
                  const Divider(height: 1),
                  _dangerTile(
                    context,
                    icon: Icons.delete_forever_outlined,
                    iconColor: Theme.of(context).colorScheme.error,
                    title: 'Delete Business Profile',
                    description: 'Permanently delete this business and its records. This cannot be undone.',
                    onTap: () => _confirmDelete(context, business),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ClosedFiscalYearsSection(key: ValueKey(_fiscalYearsRefreshToken)),
          ],
        ),
      ),
    );
  }

  Widget _dangerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: iconColor)),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCloseFiscalYear(BuildContext context, Business? business) async {
    if (business == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Close fiscal year?'),
          content: Text(
            'Closes the current fiscal year for "${business.name}". Sales, '
            'purchases, expenses, etc. all stay right here — they just '
            'become read-only. This can\'t be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Close Fiscal Year')),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.closeFiscalYear();

    if (!context.mounted) return;

    if (ok) {
      showAppSnackBar(context, 'Fiscal year closed successfully');
      setState(() => _fiscalYearsRefreshToken++);
    } else {
      showAppSnackBar(context, auth.error ?? 'Failed to close fiscal year', isError: true);
    }
  }

  Future<void> _confirmArchiveToggle(BuildContext context, bool isArchived) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isArchived ? 'Restore this business?' : 'Archive this business?'),
          content: Text(
            isArchived
                ? 'You will be able to create and edit records again.'
                : 'The business will become read-only until restored.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(isArchived ? 'Restore' : 'Archive')),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.updateCurrentBusiness({
      'status': isArchived ? 'ACTIVE' : 'ARCHIVED',
    });

    if (!context.mounted) return;

    showAppSnackBar(
      context,
      ok ? (isArchived ? 'Business restored' : 'Business archived') : (auth.error ?? 'Failed to update business status'),
      isError: !ok,
    );
  }

  Future<void> _confirmDelete(BuildContext context, Business? business) async {
    if (business == null) return;

    final controller = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final matches = controller.text.trim() == business.name;

              return AlertDialog(
                title: const Text('Delete this business?'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This permanently deletes "${business.name}" '
                        'and all records in it. This cannot be undone.',
                      ),
                      const SizedBox(height: 14),
                      Text('Type "${business.name}" to confirm:', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(controller: controller, autofocus: true, onChanged: (_) => setDialogState(() {})),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: matches ? () => Navigator.pop(dialogContext, true) : null,
                    child: const Text('Delete Forever'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !context.mounted) return;

      final auth = context.read<AuthProvider>();
      final ok = await auth.deleteCurrentBusiness();

      if (!context.mounted) return;

      if (ok) {
        Navigator.of(context).pop();
        showAppSnackBar(context, 'Business deleted');
      } else {
        showAppSnackBar(context, auth.error ?? 'Failed to delete business', isError: true);
      }
    } finally {
      controller.dispose();
    }
  }
}

/// Past closed fiscal years for the current business — read-only, so a
/// closed period stays visible/searchable even though it's no longer
/// editable. See accounts.FiscalYear on the backend.
class _ClosedFiscalYearsSection extends StatefulWidget {
  const _ClosedFiscalYearsSection({super.key});

  @override
  State<_ClosedFiscalYearsSection> createState() => _ClosedFiscalYearsSectionState();
}

class _ClosedFiscalYearsSectionState extends State<_ClosedFiscalYearsSection> {
  List<FiscalYear>? _fiscalYears;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final years = await context.read<AuthProvider>().fiscalYears();
    if (!mounted) return;
    setState(() => _fiscalYears = years);
  }

  @override
  Widget build(BuildContext context) {
    if (_fiscalYears == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_fiscalYears!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Closed Fiscal Years', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _fiscalYears!.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline, size: 20),
                  title: Text(_fiscalYears![i].label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${_fmt(_fiscalYears![i].startDate)} — ${_fmt(_fiscalYears![i].endDate)}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Closed 🔒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
