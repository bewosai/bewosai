import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
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
        final created = await _useCases.addTransaction(transaction);
        if (selectedAccountId == transaction.account) {
          transactions = [created, ...transactions];
        }
        await load();
        return true;
      });

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
