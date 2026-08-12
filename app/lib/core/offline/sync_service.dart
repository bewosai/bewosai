import 'package:flutter/foundation.dart';

import '../../features/sales/data/services/sale_service.dart';
import '../storage/token_storage.dart';
import 'app_database.dart';
import 'connectivity_service.dart';

/// Drains the offline outbox (currently just queued Sales — see
/// [AppDatabase.enqueueSale]) whenever connectivity comes back, replaying
/// each queued write against the real API in the order it was created.
///
/// A queued write that fails to sync (e.g. a validation error the user
/// would need to fix) is left in the outbox rather than dropped, and is
/// retried on the next reconnect — [onSynced] fires after each successful
/// batch so screens/providers can refresh from the server's canonical data.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _saleService = SaleService();

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  VoidCallback? onSynced;
  bool _initialized = false;
  bool _wasOnline = true;

  void init() {
    if (_initialized) return;
    _initialized = true;
    refreshPendingCount();
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
    if (ConnectivityService.instance.isOnline.value) {
      drain();
    }
  }

  void _onConnectivityChanged() {
    final online = ConnectivityService.instance.isOnline.value;
    if (online && !_wasOnline) {
      drain();
    }
    _wasOnline = online;
  }

  Future<void> refreshPendingCount() async {
    final business = await TokenStorage.instance.currentBusiness;
    final businessId = '${business?['id'] ?? ''}';
    if (businessId.isEmpty) return;
    pendingCount.value = await AppDatabase.instance.pendingSaleCount(businessId);
  }

  /// Replays every queued Sale for the active business against the real
  /// API, oldest first. Safe to call repeatedly (e.g. on every reconnect) —
  /// a business with nothing queued returns immediately.
  Future<void> drain() async {
    if (isSyncing.value) return;
    final business = await TokenStorage.instance.currentBusiness;
    final businessId = '${business?['id'] ?? ''}';
    if (businessId.isEmpty) return;

    final pending = await AppDatabase.instance.pendingSales(businessId);
    if (pending.isEmpty) return;

    isSyncing.value = true;
    var syncedAny = false;
    for (final item in pending) {
      final tempId = item['temp_id'] as int;
      final payload = Map<String, dynamic>.from(item)
        ..remove('temp_id')
        ..remove('created_at');
      try {
        await _saleService.createRaw(payload);
        await AppDatabase.instance.removePendingSale(tempId);
        syncedAny = true;
      } catch (_) {
        // Leave it queued — could be a still-flaky connection or a real
        // validation error; either way, retry on the next reconnect rather
        // than silently discarding the sale.
        break;
      }
    }
    isSyncing.value = false;
    await refreshPendingCount();
    if (syncedAny) onSynced?.call();
  }
}
