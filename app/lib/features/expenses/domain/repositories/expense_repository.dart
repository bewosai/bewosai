import 'dart:io';

import '../../data/models/expense_model.dart';

/// Domain contract for expenses.
/// Implemented by [ExpenseRepositoryImpl] → [ExpenseService].
abstract class ExpenseRepository {
  Future<List<ExpenseCategory>> categories();

  Future<ExpenseCategory> createCategory(ExpenseCategory category);

  Future<List<Expense>> list({
    int? categoryId,
    DateTime? from,
    DateTime? to,
  });

  Future<Expense> create(Expense expense, {File? receiptImage});

  Future<Expense> update(int id, Expense expense, {File? receiptImage});

  Future<void> delete(int id);
}