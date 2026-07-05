// Presentation layer — exposes business operations to screens via domain use cases
import '../../domain/repositories/business_repository.dart';
import '../../domain/usecases/business_usecases.dart';

class BusinessProvider {
  final GetDashboardUseCase _getDashboard;
  final GetMonthlyReportUseCase _getMonthly;
  final GetReportSummaryUseCase _getReportSummary;
  final GetProfitReportUseCase _getProfitReport;
  final GetInventoryReportUseCase _getInventoryReport;
  final GetReceivableAgingUseCase _getReceivableAging;
  final GetLowStockProductsUseCase _getLowStockProducts;
  final GetSalesUseCase _getSales;
  final GetSalesReturnsUseCase _getSalesReturns;
  final CreateSaleUseCase _createSale;
  final GetPurchasesUseCase _getPurchases;
  final CreatePurchaseUseCase _createPurchase;
  final GetPurchaseReturnsUseCase _getPurchaseReturns;
  final CreatePurchaseReturnUseCase _createPurchaseReturn;
  final GetExpensesUseCase _getExpenses;
  final CreateExpenseUseCase _createExpense;
  final GetProductsUseCase _getProducts;
  final GetCategoriesUseCase _getCategories;
  final GetUnitsUseCase _getUnits;
  final CreateProductUseCase _createProduct;
  final GetPartiesUseCase _getParties;
  final CreatePartyUseCase _createParty;
  final GetReceivablesUseCase _getReceivables;
  final GetPayablesUseCase _getPayables;
  final GetStaffUseCase _getStaff;
  final GetActivityLogUseCase _getActivityLog;
  final InviteStaffUseCase _inviteStaff;
  final GetRecycleBinUseCase _getRecycleBin;
  final RestoreFromBinUseCase _restoreFromBin;
  final PermanentDeleteUseCase _permanentDelete;
  final GetDayBookUseCase _getDayBook;
  final GetCashFlowUseCase _getCashFlow;
  final GetBusinessProfileUseCase _getBusinessProfile;
  final UpdateBusinessProfileUseCase _updateBusinessProfile;

  BusinessProvider(BusinessRepository repo)
      : _getDashboard = GetDashboardUseCase(repo),
        _getMonthly = GetMonthlyReportUseCase(repo),
        _getReportSummary = GetReportSummaryUseCase(repo),
        _getProfitReport = GetProfitReportUseCase(repo),
        _getInventoryReport = GetInventoryReportUseCase(repo),
        _getReceivableAging = GetReceivableAgingUseCase(repo),
        _getLowStockProducts = GetLowStockProductsUseCase(repo),
        _getSales = GetSalesUseCase(repo),
        _getSalesReturns = GetSalesReturnsUseCase(repo),
        _createSale = CreateSaleUseCase(repo),
        _getPurchases = GetPurchasesUseCase(repo),
        _createPurchase = CreatePurchaseUseCase(repo),
        _getPurchaseReturns = GetPurchaseReturnsUseCase(repo),
        _createPurchaseReturn = CreatePurchaseReturnUseCase(repo),
        _getExpenses = GetExpensesUseCase(repo),
        _createExpense = CreateExpenseUseCase(repo),
        _getProducts = GetProductsUseCase(repo),
        _getCategories = GetCategoriesUseCase(repo),
        _getUnits = GetUnitsUseCase(repo),
        _createProduct = CreateProductUseCase(repo),
        _getParties = GetPartiesUseCase(repo),
        _createParty = CreatePartyUseCase(repo),
        _getReceivables = GetReceivablesUseCase(repo),
        _getPayables = GetPayablesUseCase(repo),
        _getStaff = GetStaffUseCase(repo),
        _getActivityLog = GetActivityLogUseCase(repo),
        _inviteStaff = InviteStaffUseCase(repo),
        _getRecycleBin = GetRecycleBinUseCase(repo),
        _restoreFromBin = RestoreFromBinUseCase(repo),
        _permanentDelete = PermanentDeleteUseCase(repo),
        _getDayBook = GetDayBookUseCase(repo),
        _getCashFlow = GetCashFlowUseCase(repo),
        _getBusinessProfile = GetBusinessProfileUseCase(repo),
        _updateBusinessProfile = UpdateBusinessProfileUseCase(repo);

  Future<Map<String, dynamic>> getDashboardSummary() => _getDashboard();
  Future<List<Map<String, dynamic>>> getMonthlyReport() => _getMonthly();
  Future<Map<String, dynamic>> getReportSummary() => _getReportSummary();
  Future<Map<String, dynamic>> getProfitReport({String? dateFrom, String? dateTo}) =>
      _getProfitReport(dateFrom: dateFrom, dateTo: dateTo);
  Future<Map<String, dynamic>> getInventoryReport() => _getInventoryReport();
  Future<Map<String, dynamic>> getReceivableAging() => _getReceivableAging();
  Future<List<Map<String, dynamic>>> getLowStockProducts() => _getLowStockProducts();

  Future<List<Map<String, dynamic>>> getSales({Map<String, dynamic>? params}) =>
      _getSales(params: params);
  Future<List<Map<String, dynamic>>> getSalesReturns() => _getSalesReturns();
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) =>
      _createSale(data);

  Future<List<Map<String, dynamic>>> getPurchases({Map<String, dynamic>? params}) =>
      _getPurchases(params: params);
  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) =>
      _createPurchase(data);
  Future<List<Map<String, dynamic>>> getPurchaseReturns() => _getPurchaseReturns();
  Future<Map<String, dynamic>> createPurchaseReturn(Map<String, dynamic> data) =>
      _createPurchaseReturn(data);

  Future<List<Map<String, dynamic>>> getExpenses() => _getExpenses();
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) =>
      _createExpense(data);

  Future<List<Map<String, dynamic>>> getProducts() => _getProducts();
  Future<List<Map<String, dynamic>>> getCategories() => _getCategories();
  Future<List<Map<String, dynamic>>> getUnits() => _getUnits();
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) =>
      _createProduct(data);

  Future<List<Map<String, dynamic>>> getParties({String? partyType}) =>
      _getParties(partyType: partyType);
  Future<Map<String, dynamic>> createParty(Map<String, dynamic> data) =>
      _createParty(data);

  Future<List<Map<String, dynamic>>> getReceivables() => _getReceivables();
  Future<List<Map<String, dynamic>>> getPayables() => _getPayables();

  Future<List<Map<String, dynamic>>> getStaff() => _getStaff();
  Future<List<Map<String, dynamic>>> getActivityLog() => _getActivityLog();
  Future<void> inviteStaff(Map<String, dynamic> data) => _inviteStaff(data);

  Future<List<Map<String, dynamic>>> getRecycleBin({String? type}) =>
      _getRecycleBin(type: type);
  Future<void> restoreFromBin(String type, int id) =>
      _restoreFromBin(type, id);
  Future<void> permanentDelete(String type, int id) =>
      _permanentDelete(type, id);

  Future<Map<String, dynamic>> getDayBook({String? date}) =>
      _getDayBook(date: date);
  Future<Map<String, dynamic>> getCashFlow({String? dateFrom, String? dateTo}) =>
      _getCashFlow(dateFrom: dateFrom, dateTo: dateTo);
  Future<Map<String, dynamic>> getBusinessProfile() => _getBusinessProfile();
  Future<Map<String, dynamic>> updateBusinessProfile(Map<String, dynamic> data) =>
      _updateBusinessProfile(data);
}
