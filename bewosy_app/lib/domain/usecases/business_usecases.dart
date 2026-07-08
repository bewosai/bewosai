import '../repositories/business_repository.dart';

class GetDashboardUseCase {
  final BusinessRepository _r;
  GetDashboardUseCase(this._r);
  Future<Map<String, dynamic>> call() => _r.getDashboardSummary();
}

class GetMonthlyReportUseCase {
  final BusinessRepository _r;
  GetMonthlyReportUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getMonthlyReport();
}

class GetReportSummaryUseCase {
  final BusinessRepository _r;
  GetReportSummaryUseCase(this._r);
  Future<Map<String, dynamic>> call() => _r.getReportSummary();
}

class GetProfitReportUseCase {
  final BusinessRepository _r;
  GetProfitReportUseCase(this._r);
  Future<Map<String, dynamic>> call({String? dateFrom, String? dateTo}) =>
      _r.getProfitReport(dateFrom: dateFrom, dateTo: dateTo);
}

class GetInventoryReportUseCase {
  final BusinessRepository _r;
  GetInventoryReportUseCase(this._r);
  Future<Map<String, dynamic>> call() => _r.getInventoryReport();
}

class GetReceivableAgingUseCase {
  final BusinessRepository _r;
  GetReceivableAgingUseCase(this._r);
  Future<Map<String, dynamic>> call() => _r.getReceivableAging();
}

class GetSalesUseCase {
  final BusinessRepository _r;
  GetSalesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call({Map<String, dynamic>? params}) =>
      _r.getSales(params: params);
}

class GetSalesReturnsUseCase {
  final BusinessRepository _r;
  GetSalesReturnsUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getSalesReturns();
}

class GetPurchaseReturnsUseCase {
  final BusinessRepository _r;
  GetPurchaseReturnsUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getPurchaseReturns();
}

class CreatePurchaseReturnUseCase {
  final BusinessRepository _r;
  CreatePurchaseReturnUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createPurchaseReturn(data);
}

class CreateSaleUseCase {
  final BusinessRepository _r;
  CreateSaleUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createSale(data);
}

class GetPurchasesUseCase {
  final BusinessRepository _r;
  GetPurchasesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call({Map<String, dynamic>? params}) =>
      _r.getPurchases(params: params);
}

class CreatePurchaseUseCase {
  final BusinessRepository _r;
  CreatePurchaseUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createPurchase(data);
}

class GetExpensesUseCase {
  final BusinessRepository _r;
  GetExpensesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getExpenses();
}

class CreateExpenseUseCase {
  final BusinessRepository _r;
  CreateExpenseUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createExpense(data);
}

class GetProductsUseCase {
  final BusinessRepository _r;
  GetProductsUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getProducts();
}

class GetCategoriesUseCase {
  final BusinessRepository _r;
  GetCategoriesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getCategories();
}

class GetUnitsUseCase {
  final BusinessRepository _r;
  GetUnitsUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getUnits();
}

class GetPartiesUseCase {
  final BusinessRepository _r;
  GetPartiesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call({String? partyType}) =>
      _r.getParties(partyType: partyType);
}

class GetDayBookUseCase {
  final BusinessRepository _r;
  GetDayBookUseCase(this._r);
  Future<Map<String, dynamic>> call({String? date}) => _r.getDayBook(date: date);
}
