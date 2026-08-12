import '../../../../core/network/api_client.dart';
import '../models/sale_model.dart';

class SaleService {
  final _dio = ApiClient.instance.dio;

  Future<List<Sale>> list({String? search, String? status, DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/sales/', queryParameters: {
        'page_size': 500,
        'ordering': '-sale_date',
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Sale> get(int id) async {
    try {
      final res = await _dio.get('/sales/$id/');
      return Sale.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<String> nextNumber() async {
    try {
      final res = await _dio.get('/sales/next-number/');
      return res.data['next_number'] as String;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Sale> create(Sale sale) async {
    try {
      final res = await _dio.post('/sales/', data: sale.toJson());
      return Sale.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Same endpoint as [create], but posts an already-built write-body
  /// directly — used by [SyncService] to replay a payload that was queued
  /// while offline without needing to reconstruct a [Sale] object first.
  Future<Sale> createRaw(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('/sales/', data: payload);
      return Sale.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Sale> update(int id, Sale sale) async {
    try {
      final res = await _dio.put('/sales/$id/', data: sale.toJson());
      return Sale.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _dio.patch('/sales/$id/', data: {'status': 'CANCELLED'});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/sales/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<SaleReturn>> returns() async {
    try {
      final res = await _dio.get('/sales/returns/', queryParameters: {'page_size': 200});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => SaleReturn.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<SaleReturn> createReturn(SaleReturn saleReturn) async {
    try {
      final res = await _dio.post('/sales/returns/', data: saleReturn.toJson());
      return SaleReturn.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<Quotation>> quotations({String? status}) async {
    try {
      final res = await _dio.get('/sales/quotations/', queryParameters: {
        'page_size': 200,
        if (status != null && status.isNotEmpty) 'status': status,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => Quotation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Quotation> createQuotation(Quotation quotation) async {
    try {
      final res = await _dio.post('/sales/quotations/', data: quotation.toJson());
      return Quotation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Quotation> updateQuotation(int id, Quotation quotation) async {
    try {
      final res = await _dio.put('/sales/quotations/$id/', data: quotation.toJson());
      return Quotation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteQuotation(int id) async {
    try {
      await _dio.delete('/sales/quotations/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
