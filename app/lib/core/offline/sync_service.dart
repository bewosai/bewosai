import 'package:flutter/foundation.dart';

import '../../features/banking/data/services/banking_service.dart';
import '../../features/expenses/data/services/expense_service.dart';
import '../../features/inventory/data/services/inventory_service.dart';
import '../../features/parties/data/services/party_service.dart';
import '../../features/purchases/data/services/purchase_service.dart';
import '../../features/sales/data/services/sale_service.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import 'app_database.dart';
import 'connectivity_service.dart';

/// Drains every offline outbox — Sales (the original, dedicated
/// outbox_sales table) plus Expenses/Purchases/Party payments/Bank
/// transactions/Stock movements (the shared generic outbox, keyed by entity
/// type) — whenever connectivity comes back, replaying each queued write
/// against the real API in the order it was created.
///
/// A queued write that fails to sync (e.g. a validation error the user
/// would need to fix) is left in its outbox rather than dropped, and the
/// rest of that entity type's queue is skipped for this pass so nothing
/// after it is replayed out of order — it's retried on the next reconnect.
/// [onSynced] fires after any successful sync so screens/providers can
/// refresh from the server's canonical data.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _saleService = SaleService();
  final _expenseService = ExpenseService();
  final _purchaseService = PurchaseService();
  final _partyService = PartyService();
  final _bankingService = BankingService();
  final _inventoryService = InventoryService();

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

  Future<String> _businessId() async {
    final business = await TokenStorage.instance.currentBusiness;
    return '${business?['id'] ?? ''}';
  }

  Future<void> refreshPendingCount() async {
    final businessId = await _businessId();
    if (businessId.isEmpty) return;
    pendingCount.value = await AppDatabase.instance.totalPendingCount(businessId);
  }

  /// Replays every queued write for the active business, oldest first
  /// within each entity type. Safe to call repeatedly (e.g. on every
  /// reconnect) — a business with nothing queued returns quickly.
  Future<void> drain() async {
    if (isSyncing.value) return;
    final businessId = await _businessId();
    if (businessId.isEmpty) return;

    isSyncing.value = true;
    var syncedAny = false;
    syncedAny |= await _drainSales(businessId);
    syncedAny |= await _drainGeneric(
      businessId, 'expense', (payload) => _expenseService.createRaw(payload),
    );
    syncedAny |= await _drainGeneric(
      businessId, 'purchase', (payload) => _purchaseService.createRaw(payload),
    );
    syncedAny |= await _drainGeneric(
      businessId, 'party_payment', (payload) => _partyService.createPaymentRaw(payload),
    );
    syncedAny |= await _drainGeneric(
      businessId, 'bank_transaction', (payload) => _bankingService.createTransactionRaw(payload),
    );
    syncedAny |= await _drainGeneric(
      businessId, 'stock_movement', (payload) => _inventoryService.createStockMovementRaw(payload),
    );
    isSyncing.value = false;
    await refreshPendingCount();
    if (syncedAny) onSynced?.call();
  }

  Future<bool> _drainSales(String businessId) async {
    final pending = await AppDatabase.instance.pendingSales(businessId);
    if (pending.isEmpty) return false;

    var syncedAny = false;
    for (final item in pending) {
      final tempId = item['temp_id'] as int;
      // Already flagged by a previous pass (e.g. a duplicate invoice
      // number) — it won't succeed until the user edits and resends it, so
      // don't retry it or let it block sales queued behind it.
      if (item['sync_error'] != null) continue;
      final payload = Map<String, dynamic>.from(item)
        ..remove('temp_id')
        ..remove('created_at')
        ..remove('sync_error');
      try {
        await _saleService.createRaw(payload);
        await AppDatabase.instance.removePendingSale(tempId);
        syncedAny = true;
      } on ApiException catch (e) {
        if (e.isNetworkError) {
          // Still offline/flaky — stop here so nothing behind it is
          // replayed out of order, and retry the whole queue next reconnect.
          break;
        }
        // A real rejection from the server (e.g. this invoice number now
        // collides with one created elsewhere while it sat offline) won't
        // fix itself on retry — flag it and keep draining the rest of the
        // queue instead of blocking every sale behind it forever.
        await AppDatabase.instance.setPendingSaleError(tempId, e.message);
      } catch (_) {
        break;
      }
    }
    return syncedAny;
  }

  Future<bool> _drainGeneric(
    String businessId,
    String entityType,
    Future<void> Function(Map<String, dynamic> payload) createRaw,
  ) async {
    final pending = await AppDatabase.instance.pendingWrites(entityType, businessId);
    if (pending.isEmpty) return false;

    var syncedAny = false;
    for (final item in pending) {
      final tempId = item['temp_id'] as int;
      final payload = Map<String, dynamic>.from(item)
        ..remove('temp_id')
        ..remove('created_at');
      try {
        await createRaw(payload);
        await AppDatabase.instance.removePendingWrite(tempId);
        syncedAny = true;
      } catch (_) {
        break;
      }
    }
    return syncedAny;
  }
}
