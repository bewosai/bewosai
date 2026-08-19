import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/offline/app_database.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/offline/sync_service.dart';
import '../../../../core/storage/token_storage.dart';
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
      Purchase result;
      if (id == null && billImage == null && !await ConnectivityService.instance.checkOnline()) {
        result = await _saveOffline(purchase);
      } else {
        result = await _useCases.savePurchase(purchase, id: id, billImage: billImage);
      }
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

  /// Queues [purchase] in the local outbox instead of posting it, returning
  /// a negative-ID stand-in — [SyncService] replays it against the real API
  /// on reconnect. A bill photo always forces the normal online path (see
  /// [save]) since a File reference isn't reliably safe to persist across
  /// app restarts.
  Future<Purchase> _saveOffline(Purchase purchase) async {
    final business = await TokenStorage.instance.currentBusiness;
    final businessId = '${business?['id'] ?? ''}';
    final tempId = await AppDatabase.instance.enqueueWrite('purchase', businessId, purchase.toJson());
    await SyncService.instance.refreshPendingCount();
    return Purchase(
      id: tempId,
      billNumber: purchase.billNumber,
      supplier: purchase.supplier,
      supplierName: purchase.supplierName,
      purchaseDate: purchase.purchaseDate,
      dueDate: purchase.dueDate,
      subtotal: purchase.subtotal,
      discount: purchase.discount,
      taxRate: purchase.taxRate,
      taxAmount: purchase.taxAmount,
      total: purchase.total,
      paidAmount: purchase.paidAmount,
      dueAmount: purchase.dueAmount,
      paymentMethod: purchase.paymentMethod,
      bankAccount: purchase.bankAccount,
      status: purchase.status,
      notes: purchase.notes,
      items: purchase.items,
    );
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
