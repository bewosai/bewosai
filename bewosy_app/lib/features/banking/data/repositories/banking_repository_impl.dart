import 'dart:io';
import '../../domain/repositories/banking_repository.dart';
import '../models/banking_model.dart';
import '../services/banking_service.dart';

class BankingRepositoryImpl implements BankingRepository {
  final BankingService _service;
  BankingRepositoryImpl([BankingService? service]) : _service = service ?? BankingService();

  @override
  Future<List<BankAccount>> accounts() => _service.accounts();
  @override
  Future<BankAccount> createAccount(BankAccount account, {File? qrCode}) => _service.createAccount(account, qrCode: qrCode);
  @override
  Future<BankAccount> updateAccount(int id, BankAccount account, {File? qrCode}) => _service.updateAccount(id, account, qrCode: qrCode);
  @override
  Future<void> deleteAccount(int id) => _service.deleteAccount(id);
  @override
  Future<List<BankTransaction>> transactions({int? accountId}) => _service.transactions(accountId: accountId);
  @override
  Future<BankTransaction> createTransaction(BankTransaction transaction) => _service.createTransaction(transaction);
  @override
  Future<void> deleteTransaction(int id) => _service.deleteTransaction(id);
}
