import 'package:bewosai_app/features/purchases/data/models/purchase_model.dart';
import 'package:bewosai_app/features/sales/data/models/sale_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the actual price-calculation logic used to build a Sale/Purchase
/// invoice line by line, before it's ever sent to the server — a wrong
/// result here means every invoice generated in the app is wrong.
void main() {
  group('SaleItem.lineTotal', () {
    test('quantity * unit price, minus any discount', () {
      final item = SaleItem(productName: 'Widget', quantity: 3, unitPrice: 100, discountAmount: 20);
      expect(item.lineTotal, 280); // 3*100 - 20
    });

    test('zero discount leaves the raw quantity*price total untouched', () {
      final item = SaleItem(productName: 'Widget', quantity: 2, unitPrice: 50);
      expect(item.lineTotal, 100);
    });

    test('fractional quantities (e.g. weighed goods) compute correctly', () {
      final item = SaleItem(productName: 'Rice (kg)', quantity: 2.5, unitPrice: 80);
      expect(item.lineTotal, 200);
    });
  });

  group('PurchaseItem.lineTotal', () {
    test('quantity * unit price, minus any discount — same formula as SaleItem', () {
      final item = PurchaseItem(productName: 'Widget', quantity: 10, unitPrice: 45, discountAmount: 50);
      expect(item.lineTotal, 400); // 10*45 - 50
    });

    test('zero discount leaves the raw quantity*price total untouched', () {
      final item = PurchaseItem(productName: 'Widget', quantity: 4, unitPrice: 25);
      expect(item.lineTotal, 100);
    });
  });
}
