import '../../../../core/network/api_client.dart';
import '../models/report_models.dart';

class ReportService {
  final _dio = ApiClient.instance.dio;

  Future<DashboardSummary> dashboard() async {
    try {
      final res = await _dio.get('/reports/dashboard/');
      return DashboardSummary.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<MonthlyPoint>> monthly() async {
    try {
      final res = await _dio.get('/reports/monthly/');
      return (res.data as List).map((e) => MonthlyPoint.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<SalesReport> salesReport({DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/sales/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return SalesReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<ProfitReport> profitReport({DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/profit/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return ProfitReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<InventoryReport> inventoryReport() async {
    try {
      final res = await _dio.get('/reports/inventory/');
      return InventoryReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<ReceivableAging> receivableAging() async {
    try {
      final res = await _dio.get('/reports/receivable-aging/');
      return ReceivableAging.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<DayBook> dayBook(DateTime date) async {
    try {
      final res = await _dio.get('/reports/day-book/', queryParameters: {
        'date': date.toIso8601String().split('T').first,
      });
      return DayBook.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CashFlow> cashFlow({DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/cash-flow/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return CashFlow.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<ExpenseReport> expenseReport({DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/expenses/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return ExpenseReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<StockReport> stockReport() async {
    try {
      final res = await _dio.get('/reports/stock/');
      return StockReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CashInHand> cashInHand({DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/cash-in-hand/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return CashInHand.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<BankAccountSummary>> bankAccounts() async {
    try {
      final res = await _dio.get('/reports/bank-statement/');
      final list = (res.data as Map<String, dynamic>)['accounts'] as List? ?? [];
      return list.map((e) => BankAccountSummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<BankStatement> bankStatement(int accountId, {DateTime? from, DateTime? to}) async {
    try {
      final res = await _dio.get('/reports/bank-statement/', queryParameters: {
        'account': accountId,
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
      });
      return BankStatement.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<AllTransactionsReport> allTransactions({DateTime? from, DateTime? to, String? type}) async {
    try {
      final res = await _dio.get('/reports/all-transactions/', queryParameters: {
        if (from != null) 'date_from': from.toIso8601String().split('T').first,
        if (to != null) 'date_to': to.toIso8601String().split('T').first,
        if (type != null && type.isNotEmpty) 'type': type,
      });
      return AllTransactionsReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
