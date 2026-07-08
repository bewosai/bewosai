import '../../domain/repositories/business_repository.dart';
import '../services/api_service.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final ApiService _api;
  BusinessRepositoryImpl(this._api);

  List<Map<String, dynamic>> _list(dynamic data) =>
      List<Map<String, dynamic>>.from(
          (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  Map<String, dynamic> _map(dynamic data) =>
      Map<String, dynamic>.from(data as Map? ?? {});

  @override
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await _api.get('/reports/dashboard/');
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getMonthlyReport() async {
    final res = await _api.get('/reports/monthly/');
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> getReportSummary() async {
    final res = await _api.get('/reports/dashboard/');
    return _map(res.data);
  }

  @override
  Future<Map<String, dynamic>> getProfitReport({String? dateFrom, String? dateTo}) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final res = await _api.get('/reports/profit/', params: params.isEmpty ? null : params);
    return _map(res.data);
  }

  @override
  Future<Map<String, dynamic>> getInventoryReport() async {
    final res = await _api.get('/reports/inventory/');
    return _map(res.data);
  }

  @override
  Future<Map<String, dynamic>> getReceivableAging() async {
    final res = await _api.get('/reports/receivable-aging/');
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getSales({Map<String, dynamic>? params}) async {
    final res = await _api.get('/sales/', params: params);
    return _list(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesReturns() async {
    final res = await _api.get('/sales/returns/');
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final res = await _api.post('/sales/', data: data);
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getPurchases({Map<String, dynamic>? params}) async {
    final res = await _api.get('/purchases/', params: params);
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) async {
    final res = await _api.post('/purchases/', data: data);
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getPurchaseReturns() async {
    final res = await _api.get('/purchases/returns/');
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> createPurchaseReturn(Map<String, dynamic> data) async {
    final res = await _api.post('/purchases/returns/', data: data);
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final res = await _api.get('/expenses/');
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final res = await _api.post('/expenses/', data: data);
    return _map(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await _api.get('/inventory/products/');
    return _list(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await _api.get('/inventory/categories/');
    return _list(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getUnits() async {
    final res = await _api.get('/inventory/units/');
    return _list(res.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getParties({String? partyType}) async {
    final params = partyType != null ? {'party_type': partyType} : null;
    final res = await _api.get('/parties/', params: params);
    return _list(res.data);
  }

  @override
  Future<Map<String, dynamic>> getDayBook({String? date}) async {
    final params = date != null ? {'date': date} : null;
    final res = await _api.get('/reports/day-book/', params: params);
    return _map(res.data);
  }
}
