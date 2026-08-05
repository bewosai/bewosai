import 'dart:io';
import '../../domain/repositories/purchase_repository.dart';
import '../models/purchase_model.dart';
import '../services/purchase_service.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  final PurchaseService _service;
  PurchaseRepositoryImpl([PurchaseService? service]) : _service = service ?? PurchaseService();

  @override
  Future<List<Purchase>> list({int? supplierId, DateTime? from, DateTime? to}) =>
      _service.list(supplierId: supplierId, from: from, to: to);

  @override
  Future<Purchase> get(int id) => _service.get(id);

  @override
  Future<String> nextNumber() => _service.nextNumber();

  @override
  Future<Purchase> create(Purchase purchase, {File? billImage}) => _service.create(purchase, billImage: billImage);

  @override
  Future<Purchase> update(int id, Purchase purchase, {File? billImage}) => _service.update(id, purchase, billImage: billImage);

  @override
  Future<void> delete(int id) => _service.delete(id);

  @override
  Future<List<PurchaseReturn>> returns() => _service.returns();

  @override
  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn) => _service.createReturn(purchaseReturn);
}
