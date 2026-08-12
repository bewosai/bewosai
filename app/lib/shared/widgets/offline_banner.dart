import 'package:flutter/material.dart';

import '../../core/i18n/translations.dart';
import '../../core/offline/connectivity_service.dart';
import '../../core/offline/sync_service.dart';
import '../../core/theme/app_colors.dart';

/// Slim app-wide strip shown above the body on every tab of [MainShell]:
/// "you're offline" while there's no connectivity, or "syncing…" right after
/// it comes back and queued sales are being replayed. Collapses to nothing
/// once there's nothing to report.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ConnectivityService.instance.isOnline,
        SyncService.instance.isSyncing,
        SyncService.instance.pendingCount,
      ]),
      builder: (context, _) {
        final online = ConnectivityService.instance.isOnline.value;
        final syncing = SyncService.instance.isSyncing.value;
        final pending = SyncService.instance.pendingCount.value;

        if (online && !syncing && pending == 0) return const SizedBox.shrink();

        final String message;
        final Color color;
        final IconData icon;
        if (!online) {
          message = t('offlineBanner');
          color = AppColors.warning;
          icon = Icons.cloud_off_outlined;
        } else {
          message = pending > 0 ? '${t('syncingPending')} ($pending)' : t('syncingPending');
          color = AppColors.info;
          icon = Icons.sync;
        }

        return Container(
          width: double.infinity,
          color: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}
