import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/offline/app_database.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/offline/sync_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/banking_model.dart';
import '../../domain/usecases/banking_usecases.dart';

class BankingProvider extends ChangeNotifier {
  final _useCases = BankingUseCases();

  List<BankAccount> accounts = [];
  List<BankTransaction> transactions = [];
  int? selectedAccountId;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      accounts = await _useCases.listAccounts();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> selectAccount(int id) async {
    selectedAccountId = id;
    notifyListeners();
    try {
      transactions = await _useCases.listTransactions(accountId: id);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> saveAccount(BankAccount account, {int? id, File? qrCode}) => _guard(() async {
        if (id != null) {
          final updated = await _useCases.saveAccount(account, id: id, qrCode: qrCode);
          accounts = accounts.map((a) => a.id == id ? updated : a).toList();
        } else {
          final created = await _useCases.saveAccount(account, qrCode: qrCode);
          accounts = [...accounts, created];
        }
        return true;
      });

  Future<bool> deleteAccount(int id) => _guard(() async {
        await _useCases.deleteAccount(id);
        accounts = accounts.where((a) => a.id != id).toList();
        if (selectedAccountId == id) {
          selectedAccountId = null;
          transactions = [];
        }
        return true;
      });

  Future<bool> addTransaction(BankTransaction transaction) => _guard(() async {
        if (!await ConnectivityService.instance.checkOnline()) {
          final queued = await _saveTransactionOffline(transaction);
          if (selectedAccountId == transaction.account) {
            transactions = [queued, ...transactions];
          }
          return true;
        }
        final created = await _useCases.addTransaction(transaction);
        if (selectedAccountId == transaction.account) {
          transactions = [created, ...transactions];
        }
        await load();
        return true;
      });

  /// Queues [transaction] in the local outbox instead of posting it,
  /// returning a negative-ID stand-in — [SyncService] replays it against the
  /// real API on reconnect. Skips the usual post-save [load] since the
  /// server-side balance hasn't actually moved yet.
  Future<BankTransaction> _saveTransactionOffline(BankTransaction transaction) async {
    final business = await TokenStorage.instance.currentBusiness;
    final businessId = '${business?['id'] ?? ''}';
    final tempId = await AppDatabase.instance.enqueueWrite('bank_transaction', businessId, transaction.toJson());
    await SyncService.instance.refreshPendingCount();
    return BankTransaction(
      id: tempId,
      account: transaction.account,
      accountName: transaction.accountName,
      transactionType: transaction.transactionType,
      amount: transaction.amount,
      date: transaction.date,
      description: transaction.description,
      reference: transaction.reference,
    );
  }

  Future<bool> deleteTransaction(int id) => _guard(() async {
        await _useCases.deleteTransaction(id);
        transactions = transactions.where((t) => t.id != id).toList();
        await load();
        return true;
      });

  double get totalBalance => accounts.fold(0.0, (sum, a) => sum + a.balance);

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
