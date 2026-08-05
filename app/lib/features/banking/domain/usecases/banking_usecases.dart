import 'dart:io';
import '../../data/models/banking_model.dart';
import '../../data/repositories/banking_repository_impl.dart';
import '../repositories/banking_repository.dart';

class BankingUseCases {
  final BankingRepository _repository;
  BankingUseCases([BankingRepository? repository]) : _repository = repository ?? BankingRepositoryImpl();

  Future<List<BankAccount>> listAccounts() => _repository.accounts();

  Future<BankAccount> saveAccount(BankAccount account, {int? id, File? qrCode}) =>
      id != null ? _repository.updateAccount(id, account, qrCode: qrCode) : _repository.createAccount(account, qrCode: qrCode);

  Future<void> deleteAccount(int id) => _repository.deleteAccount(id);

  Future<List<BankTransaction>> listTransactions({int? accountId}) => _repository.transactions(accountId: accountId);

  Future<BankTransaction> addTransaction(BankTransaction transaction) => _repository.createTransaction(transaction);

  Future<void> deleteTransaction(int id) => _repository.deleteTransaction(id);
}
