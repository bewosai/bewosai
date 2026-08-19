import 'dart:io';

import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../repositories/expense_repository.dart';

/// Domain use-cases for expenses.
/// Presentation (provider) should call this, not the service directly.
class ExpenseUseCases {
  final ExpenseRepository _repository;

  ExpenseUseCases([ExpenseRepository? repository])
      : _repository = repository ?? ExpenseRepositoryImpl();

  Future<List<ExpenseCategory>> listCategories() {
    return _repository.categories();
  }

  Future<ExpenseCategory> createCategory(ExpenseCategory category) {
    return _repository.createCategory(category);
  }

  Future<List<Expense>> listExpenses({
    int? categoryId,
    DateTime? from,
    DateTime? to,
  }) {
    return _repository.list(
      categoryId: categoryId,
      from: from,
      to: to,
    );
  }

  /// Create when [id] is null; update when [id] is set. [receiptImage] is
  /// only sent when the user actually picked/changed a photo — updating
  /// without it leaves the existing receipt image untouched.
  Future<Expense> saveExpense(
    Expense expense, {
    int? id,
    File? receiptImage,
  }) {
    if (id != null) {
      return _repository.update(id, expense, receiptImage: receiptImage);
    }
    return _repository.create(expense, receiptImage: receiptImage);
  }

  Future<void> deleteExpense(int id) {
    return _repository.delete(id);
  }
}