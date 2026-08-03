import 'dart:io';
import '../../data/models/banking_model.dart';

abstract class BankingRepository {
  Future<List<BankAccount>> accounts();
  Future<BankAccount> createAccount(BankAccount account, {File? qrCode});
  Future<BankAccount> updateAccount(int id, BankAccount account, {File? qrCode});
  Future<void> deleteAccount(int id);
  Future<List<BankTransaction>> transactions({int? accountId});
  Future<BankTransaction> createTransaction(BankTransaction transaction);
  Future<void> deleteTransaction(int id);
}
