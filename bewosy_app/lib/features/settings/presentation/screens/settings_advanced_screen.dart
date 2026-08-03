import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/data/models/business_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsAdvancedScreen extends StatelessWidget {
  const SettingsAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = auth.currentBusiness;
    final isArchived = business?.status == 'ARCHIVED';

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced'), actions: const [HomeLogoButton()]),
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
                        'Archive the current business and create a new profile with carried-forward opening balance.',
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
            '"${business.name}" will be archived and a new business profile '
            'will be created with the carried-forward opening balance.',
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
      Navigator.of(context).pop();
      showAppSnackBar(context, 'Fiscal year closed successfully');
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
