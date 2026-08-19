import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/app_database.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/offline/sync_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/expense_model.dart';
import '../../domain/usecases/expense_usecases.dart';

/// Seeded only when the API returns zero categories.
const _defaultExpenseCategories = <String>[
  'Daily',
  'Purchase',
  'Utility',
  'Staff',
  'Other',
];

class ExpenseProvider extends ChangeNotifier {
  final ExpenseUseCases _useCases;

  ExpenseProvider([ExpenseUseCases? useCases])
      : _useCases = useCases ?? ExpenseUseCases();

  List<Expense> expenses = [];
  List<ExpenseCategory> categories = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      categories = await _useCases.listCategories();
      if (categories.isEmpty) {
        await _seedDefaultCategories();
      }
      expenses = await _useCases.listExpenses();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _seedDefaultCategories() async {
    for (final name in _defaultExpenseCategories) {
      try {
        final created = await _useCases.createCategory(
          ExpenseCategory(
            id: 0,
            name: name,
            expenseType: name.toUpperCase(), // DAILY, PURCHASE, ...
          ),
        );
        categories = [...categories, created];
      } catch (_) {
        // Best-effort seed; ignore individual failures.
      }
    }
  }

  Future<bool> save(Expense expense, {int? id, File? receiptImage}) {
    return _guard(() async {
      if (id != null) {
        final updated = await _useCases.saveExpense(expense, id: id, receiptImage: receiptImage);
        expenses = [
          for (final e in expenses)
            if (e.id == id) updated else e,
        ];
      } else if (receiptImage == null && !await ConnectivityService.instance.checkOnline()) {
        final queued = await _saveOffline(expense);
        expenses = [queued, ...expenses];
      } else {
        final created = await _useCases.saveExpense(
          expense,
          receiptImage: receiptImage,
        );
        expenses = [created, ...expenses];
      }
      return true;
    });
  }

  /// Queues [expense] in the local outbox instead of posting it — [SyncService]
  /// replays it against the real API on reconnect. A receipt photo always
  /// forces the normal online path (see [save]) since a File reference isn't
  /// reliably safe to persist across app restarts.
  Future<Expense> _saveOffline(Expense expense) async {
    final businessId = await _businessId();
    final tempId = await AppDatabase.instance.enqueueWrite('expense', businessId, expense.toJson());
    await SyncService.instance.refreshPendingCount();
    return expense.copyWith(id: tempId);
  }

  Future<String> _businessId() async {
    final business = await TokenStorage.instance.currentBusiness;
    return '${business?['id'] ?? ''}';
  }

  Future<bool> delete(int id) {
    return _guard(() async {
      await _useCases.deleteExpense(id);
      expenses = expenses.where((e) => e.id != id).toList();
      return true;
    });
  }

  double get thisMonthTotal {
    final now = DateTime.now();
    return expenses
        .where(
          (e) =>
              e.date != null &&
              e.date!.year == now.year &&
              e.date!.month == now.month,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get allTimeTotal =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      return result;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}