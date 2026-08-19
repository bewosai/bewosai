import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/banking_model.dart';

class BankingService {
  final _dio = ApiClient.instance.dio;

  Future<List<BankAccount>> accounts() async {
    try {
      final res = await _dio.get('/banking/accounts/', queryParameters: {'page_size': 200});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => BankAccount.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<BankAccount> createAccount(BankAccount account, {File? qrCode}) async {
    try {
      final res = qrCode == null
          ? await _dio.post('/banking/accounts/', data: account.toJson())
          : await _dio.post('/banking/accounts/', data: FormData.fromMap({
              ...account.toJson(),
              'qr_code': await MultipartFile.fromFile(qrCode.path),
            }));
      return BankAccount.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<BankAccount> updateAccount(int id, BankAccount account, {File? qrCode}) async {
    try {
      final res = qrCode == null
          ? await _dio.put('/banking/accounts/$id/', data: account.toJson())
          : await _dio.put('/banking/accounts/$id/', data: FormData.fromMap({
              ...account.toJson(),
              'qr_code': await MultipartFile.fromFile(qrCode.path),
            }));
      return BankAccount.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteAccount(int id) async {
    try {
      await _dio.delete('/banking/accounts/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<BankTransaction>> transactions({int? accountId}) async {
    try {
      final res = await _dio.get('/banking/transactions/', queryParameters: {
        'page_size': 500,
        'account': ?accountId,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => BankTransaction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<BankTransaction> createTransaction(BankTransaction transaction) async {
    try {
      final res = await _dio.post('/banking/transactions/', data: transaction.toJson());
      return BankTransaction.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Posts an already-server-shaped payload directly — used by [SyncService]
  /// to replay a transaction queued while offline.
  Future<BankTransaction> createTransactionRaw(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('/banking/transactions/', data: payload);
      return BankTransaction.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _dio.delete('/banking/transactions/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
