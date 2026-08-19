import 'dart:io';

import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';

/// Data-layer implementation of [ExpenseRepository].
/// Delegates to [ExpenseService]; no business logic here.
class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseService _service;

  ExpenseRepositoryImpl([ExpenseService? service])
      : _service = service ?? ExpenseService();

  @override
  Future<List<ExpenseCategory>> categories() {
    return _service.categories();
  }

  @override
  Future<ExpenseCategory> createCategory(ExpenseCategory category) {
    return _service.createCategory(category);
  }

  @override
  Future<List<Expense>> list({
    int? categoryId,
    DateTime? from,
    DateTime? to,
  }) {
    return _service.list(
      categoryId: categoryId,
      from: from,
      to: to,
    );
  }

  @override
  Future<Expense> create(Expense expense, {File? receiptImage}) {
    return _service.create(expense, receiptImage: receiptImage);
  }

  @override
  Future<Expense> update(int id, Expense expense, {File? receiptImage}) {
    return _service.update(id, expense, receiptImage: receiptImage);
  }

  @override
  Future<void> delete(int id) {
    return _service.delete(id);
  }
}