import 'dart:io';
import '../../data/models/purchase_model.dart';
import '../../data/repositories/purchase_repository_impl.dart';
import '../repositories/purchase_repository.dart';

class PurchaseUseCases {
  final PurchaseRepository _repository;
  PurchaseUseCases([PurchaseRepository? repository]) : _repository = repository ?? PurchaseRepositoryImpl();

  Future<List<Purchase>> listPurchases({int? supplierId, DateTime? from, DateTime? to}) =>
      _repository.list(supplierId: supplierId, from: from, to: to);

  Future<String> nextBillNumber() => _repository.nextNumber();

  Future<Purchase> savePurchase(Purchase purchase, {int? id, File? billImage}) =>
      id != null ? _repository.update(id, purchase, billImage: billImage) : _repository.create(purchase, billImage: billImage);

  Future<void> deletePurchase(int id) => _repository.delete(id);

  Future<List<PurchaseReturn>> listReturns() => _repository.returns();

  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn) => _repository.createReturn(purchaseReturn);
}
