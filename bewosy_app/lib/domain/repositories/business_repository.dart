abstract class BusinessRepository {
  // Dashboard & Reports
  Future<Map<String, dynamic>> getDashboardSummary();
  Future<List<Map<String, dynamic>>> getMonthlyReport();
  Future<Map<String, dynamic>> getReportSummary();

  // Sales
  Future<List<Map<String, dynamic>>> getSales({Map<String, dynamic>? params});
  Future<List<Map<String, dynamic>>> getSalesReturns();
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data);

  // Purchases
  Future<List<Map<String, dynamic>>> getPurchases({Map<String, dynamic>? params});
  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data);

  // Expenses
  Future<List<Map<String, dynamic>>> getExpenses();
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data);

  // Inventory
  Future<List<Map<String, dynamic>>> getProducts();
  Future<List<Map<String, dynamic>>> getCategories();
  Future<List<Map<String, dynamic>>> getUnits();
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data);

  // Parties
  Future<List<Map<String, dynamic>>> getParties({String? partyType});
  Future<Map<String, dynamic>> createParty(Map<String, dynamic> data);

  // Payments
  Future<List<Map<String, dynamic>>> getReceivables();
  Future<List<Map<String, dynamic>>> getPayables();

  // Staff
  Future<List<Map<String, dynamic>>> getStaff();
  Future<List<Map<String, dynamic>>> getActivityLog();
  Future<void> inviteStaff(Map<String, dynamic> data);

  // Recycle Bin
  Future<List<Map<String, dynamic>>> getRecycleBin({String? type});
  Future<void> restoreFromBin(String type, int id);
  Future<void> permanentDelete(String type, int id);
}
