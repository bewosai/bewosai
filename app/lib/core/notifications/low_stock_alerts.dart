import 'package:shared_preferences/shared_preferences.dart';

import '../../features/inventory/data/models/inventory_model.dart';
import 'notification_service.dart';

/// Phone notification when a product reaches its low-stock alert level —
/// once per product, not on every reload: it's remembered (per business) until
/// the product is restocked above the level, after which it can alert again.
/// Uses the server's own is_low_stock, so it always matches the Low Stock
/// count on the dashboard and the LOW badge in Inventory.
class LowStockAlerts {
  LowStockAlerts._();

  static const _maxIndividual = 3;
  // Notification ids well away from the reminder ids (which are sale ids).
  static const _idBase = 900000000;

  static Future<void> check(List<Product> products, {required String businessId}) async {
    if (businessId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'low_stock_notified:$businessId';
    final notified = (prefs.getStringList(key) ?? const []).toSet();

    final (:fresh, :remember) = plan(products, notified);
    // Android 13+ shows nothing without permission — ask only when there's
    // actually something to warn about (no-op if already granted).
    if (fresh.isNotEmpty) await NotificationService.instance.requestPermission();
    for (final p in fresh.take(_maxIndividual)) {
      final unit = p.unitName.isEmpty ? '' : ' ${p.unitName}';
      await NotificationService.instance.showNow(
        id: _idBase + p.id,
        title: 'Low stock: ${p.name}',
        body: '${_fmt(p.stockQuantity)}$unit left (alert at ${_fmt(p.lowStockThreshold)}). Time to reorder.',
      );
    }
    if (fresh.length > _maxIndividual) {
      await NotificationService.instance.showNow(
        id: _idBase,
        title: 'Low stock: ${fresh.length - _maxIndividual} more products',
        body: 'Open Inventory → Low Stock to see them all.',
      );
    }
    await prefs.setStringList(key, remember.toList());
  }

  /// Which products to notify about now ([fresh]) and the set of product ids
  /// to remember as already-notified ([remember]). Pure, so it's testable:
  /// a product alerts once when it goes low, is forgotten once it's
  /// restocked above its level, and can then alert again.
  static ({List<Product> fresh, Set<String> remember}) plan(List<Product> products, Set<String> notified) {
    final low = products.where((p) => p.isProduct && p.isActive && p.isLowStock).toList();
    final lowIds = {for (final p in low) '${p.id}'};
    final listed = {for (final p in products) '${p.id}'};
    // Products not in this list (deleted) are kept as-is; restocked ones are dropped.
    final remember = {...notified}..removeWhere((id) => listed.contains(id) && !lowIds.contains(id));
    final fresh = low.where((p) => !remember.contains('${p.id}')).toList();
    return (fresh: fresh, remember: {...remember, ...lowIds});
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
