import 'package:bewosai_app/core/notifications/low_stock_alerts.dart';
import 'package:bewosai_app/features/inventory/data/models/inventory_model.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p(int id, {double stock = 10, double level = 5, bool service = false, bool active = true}) => Product(
      id: id,
      name: 'P$id',
      categoryName: '',
      itemType: service ? ItemType.service : ItemType.product,
      unitName: 'pcs',
      description: '',
      purchasePrice: 0,
      salePrice: 0,
      stockQuantity: stock,
      lowStockThreshold: level,
      isLowStock: !service && stock <= level,
      barcode: '',
      isActive: active,
    );

void main() {
  test('alerts a product once when it goes low', () {
    final first = LowStockAlerts.plan([_p(1, stock: 4), _p(2)], {});
    expect(first.fresh.map((p) => p.id), [1]);
    expect(first.remember, {'1'});

    final again = LowStockAlerts.plan([_p(1, stock: 3), _p(2)], first.remember);
    expect(again.fresh, isEmpty, reason: 'still low — no repeat notification');
    expect(again.remember, {'1'});
  });

  test('alerts again after the product was restocked and goes low again', () {
    final restocked = LowStockAlerts.plan([_p(1, stock: 50)], {'1'});
    expect(restocked.fresh, isEmpty);
    expect(restocked.remember, isEmpty);

    final lowAgain = LowStockAlerts.plan([_p(1, stock: 2)], restocked.remember);
    expect(lowAgain.fresh.map((p) => p.id), [1]);
  });

  test('never alerts for services or inactive products', () {
    final r = LowStockAlerts.plan([_p(1, stock: 0, level: 0, service: true), _p(2, stock: 0, active: false)], {});
    expect(r.fresh, isEmpty);
  });

  test('stock exactly at the alert level counts as low', () {
    expect(LowStockAlerts.plan([_p(1, stock: 5, level: 5)], {}).fresh.length, 1);
  });

  test('keeps memory for products missing from the list', () {
    expect(LowStockAlerts.plan([_p(2)], {'1'}).remember, {'1'});
  });
}
