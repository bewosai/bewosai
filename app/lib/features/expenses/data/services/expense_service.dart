import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final _dio = ApiClient.instance.dio;

  Future<List<ExpenseCategory>> categories() async {
    try {
      final res = await _dio.get(
        '/expenses/categories/',
        queryParameters: {'page_size': 200},
      );
      return _parseList(res.data, ExpenseCategory.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<ExpenseCategory> createCategory(ExpenseCategory category) async {
    try {
      final res = await _dio.post(
        '/expenses/categories/',
        data: category.toJson(),
      );
      return ExpenseCategory.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<Expense>> list({
    int? categoryId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await _dio.get(
        '/expenses/',
        queryParameters: {
          'page_size': 500,
          'ordering': '-date',
          if (categoryId != null) 'category': categoryId,
          if (from != null) 'date_from': Formatters.apiDate(from),
          if (to != null) 'date_to': Formatters.apiDate(to),
        },
      );
      return _parseList(res.data, Expense.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Expense> create(Expense expense, {File? receiptImage}) async {
    try {
      final Response res;
      if (receiptImage == null) {
        res = await _dio.post('/expenses/', data: expense.toJson());
      } else {
        final map = <String, dynamic>{
          for (final e in expense.toJson().entries)
            e.key: e.value is num || e.value is bool
                ? e.value
                : e.value?.toString(),
        };
        map['receipt_image'] = await MultipartFile.fromFile(
          receiptImage.path,
          filename: receiptImage.path.split(RegExp(r'[/\\]')).last,
        );
        res = await _dio.post(
          '/expenses/',
          data: FormData.fromMap(map),
        );
      }
      return Expense.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Expense> update(int id, Expense expense) async {
    try {
      final res = await _dio.patch(
        '/expenses/$id/',
        data: expense.toJson(),
      );
      return Expense.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/expenses/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    throw ApiException('Unexpected response format');
  }

  static List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data is Map
        ? (data['results'] as List? ?? const [])
        : (data is List ? data : const []);
    return raw
        .whereType<Map>()
        .map((e) => fromJson(
              e is Map<String, dynamic>
                  ? e
                  : e.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }
}