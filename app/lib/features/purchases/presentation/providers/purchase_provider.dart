import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/purchase_model.dart';
import '../../domain/usecases/purchase_usecases.dart';

class PurchaseProvider extends ChangeNotifier {
  final _useCases = PurchaseUseCases();

  List<Purchase> purchases = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      purchases = await _useCases.listPurchases();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String> nextNumber() => _useCases.nextBillNumber();

  Future<Purchase?> save(Purchase purchase, {int? id, File? billImage}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _useCases.savePurchase(purchase, id: id, billImage: billImage);
      if (id != null) {
        purchases = purchases.map((p) => p.id == id ? result : p).toList();
      } else {
        purchases = [result, ...purchases];
      }
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) => _guard(() async {
        await _useCases.deletePurchase(id);
        purchases = purchases.where((p) => p.id != id).toList();
        return true;
      });

  Future<bool> createReturn(PurchaseReturn purchaseReturn) => _guard(() async {
        await _useCases.createReturn(purchaseReturn);
        await load();
        return true;
      });

  double get thisMonthTotal {
    final now = DateTime.now();
    return purchases
        .where((p) => p.purchaseDate != null && p.purchaseDate!.year == now.year && p.purchaseDate!.month == now.month)
        .fold(0.0, (sum, p) => sum + p.total);
  }

  double get totalPayable => purchases.where((p) => p.status == 'CONFIRMED').fold(0.0, (sum, p) => sum + p.dueAmount);

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
