import 'dart:io';
import '../../data/models/purchase_model.dart';

abstract class PurchaseRepository {
  Future<List<Purchase>> list({int? supplierId, DateTime? from, DateTime? to});
  Future<Purchase> get(int id);
  Future<String> nextNumber();
  Future<Purchase> create(Purchase purchase, {File? billImage});
  Future<Purchase> update(int id, Purchase purchase, {File? billImage});
  Future<void> delete(int id);
  Future<List<PurchaseReturn>> returns();
  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn);
}
