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

class CreateProductUseCase {
  final BusinessRepository _r;
  CreateProductUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createProduct(data);
}

class GetPartiesUseCase {
  final BusinessRepository _r;
  GetPartiesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call({String? partyType}) =>
      _r.getParties(partyType: partyType);
}

class CreatePartyUseCase {
  final BusinessRepository _r;
  CreatePartyUseCase(this._r);
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      _r.createParty(data);
}

class GetReceivablesUseCase {
  final BusinessRepository _r;
  GetReceivablesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getReceivables();
}

class GetPayablesUseCase {
  final BusinessRepository _r;
  GetPayablesUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getPayables();
}

class GetStaffUseCase {
  final BusinessRepository _r;
  GetStaffUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getStaff();
}

class GetActivityLogUseCase {
  final BusinessRepository _r;
  GetActivityLogUseCase(this._r);
  Future<List<Map<String, dynamic>>> call() => _r.getActivityLog();
}

class InviteStaffUseCase {
  final BusinessRepository _r;
  InviteStaffUseCase(this._r);
  Future<void> call(Map<String, dynamic> data) => _r.inviteStaff(data);
}

class GetRecycleBinUseCase {
  final BusinessRepository _r;
  GetRecycleBinUseCase(this._r);
  Future<List<Map<String, dynamic>>> call({String? type}) =>
      _r.getRecycleBin(type: type);
}

class RestoreFromBinUseCase {
  final BusinessRepository _r;
  RestoreFromBinUseCase(this._r);
  Future<void> call(String type, int id) => _r.restoreFromBin(type, id);
}

class PermanentDeleteUseCase {
  final BusinessRepository _r;
  PermanentDeleteUseCase(this._r);
  Future<void> call(String type, int id) => _r.permanentDelete(type, id);
}
