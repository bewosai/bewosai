import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/purchase_model.dart';

class PurchaseService {
  final _dio = ApiClient.instance.dio;

  Future<List<Purchase>> list({int? supplierId, DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/purchases/', queryParameters: {
        'page_size': 500,
        if (supplierId != null) 'supplier': supplierId,
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => Purchase.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Purchase> get(int id) async {
    try {
      final res = await _dio.get('/purchases/$id/');
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<String> nextNumber() async {
    try {
      final res = await _dio.get('/purchases/next-number/');
      return res.data['next_number'] as String;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Purchase> create(Purchase purchase, {File? billImage}) async {
    try {
      final res = billImage == null
          ? await _dio.post('/purchases/', data: purchase.toJson())
          : await _dio.post('/purchases/', data: FormData.fromMap({
              ...purchase.toJson().map((k, v) => MapEntry(k, k == 'items' ? _jsonList(v) : v)),
              'bill_image': await MultipartFile.fromFile(billImage.path),
            }));
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Purchase> update(int id, Purchase purchase, {File? billImage}) async {
    try {
      final res = billImage == null
          ? await _dio.put('/purchases/$id/', data: purchase.toJson())
          : await _dio.put('/purchases/$id/', data: FormData.fromMap({
              ...purchase.toJson().map((k, v) => MapEntry(k, k == 'items' ? _jsonList(v) : v)),
              'bill_image': await MultipartFile.fromFile(billImage.path),
            }));
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  String _jsonList(dynamic items) => items.toString();

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/purchases/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<PurchaseReturn>> returns() async {
    try {
      final res = await _dio.get('/purchases/returns/', queryParameters: {'page_size': 200});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => PurchaseReturn.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn) async {
    try {
      final res = await _dio.post('/purchases/returns/', data: purchaseReturn.toJson());
      return PurchaseReturn.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
