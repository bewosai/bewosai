abstract class BusinessRepository {
  // Dashboard & Reports
  Future<Map<String, dynamic>> getDashboardSummary();
  Future<List<Map<String, dynamic>>> getMonthlyReport();
  Future<Map<String, dynamic>> getReportSummary();
  Future<Map<String, dynamic>> getProfitReport({String? dateFrom, String? dateTo});
  Future<Map<String, dynamic>> getInventoryReport();
  Future<Map<String, dynamic>> getReceivableAging();

  // Sales
  Future<List<Map<String, dynamic>>> getSales({Map<String, dynamic>? params});
  Future<List<Map<String, dynamic>>> getSalesReturns();
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data);

  // Purchases
  Future<List<Map<String, dynamic>>> getPurchases({Map<String, dynamic>? params});
  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getPurchaseReturns();
  Future<Map<String, dynamic>> createPurchaseReturn(Map<String, dynamic> data);

  // Expenses
  Future<List<Map<String, dynamic>>> getExpenses();
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data);

  // Inventory
  Future<List<Map<String, dynamic>>> getProducts();
  Future<List<Map<String, dynamic>>> getCategories();
  Future<List<Map<String, dynamic>>> getUnits();

  // Parties
  Future<List<Map<String, dynamic>>> getParties({String? partyType});

  // Nepal-specific reports
  Future<Map<String, dynamic>> getDayBook({String? date});
}
