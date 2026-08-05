import '../../data/models/report_models.dart';

abstract class ReportRepository {
  Future<DashboardSummary> dashboard();
  Future<List<MonthlyPoint>> monthly();
  Future<SalesReport> salesReport({DateTime? from, DateTime? to});
  Future<ProfitReport> profitReport({DateTime? from, DateTime? to});
  Future<InventoryReport> inventoryReport();
  Future<ReceivableAging> receivableAging();
  Future<DayBook> dayBook(DateTime date);
  Future<CashFlow> cashFlow({DateTime? from, DateTime? to});
  Future<ExpenseReport> expenseReport({DateTime? from, DateTime? to});
  Future<StockReport> stockReport();
  Future<CashInHand> cashInHand({DateTime? from, DateTime? to});
  Future<List<BankAccountSummary>> bankAccounts();
  Future<BankStatement> bankStatement(int accountId, {DateTime? from, DateTime? to});
  Future<AllTransactionsReport> allTransactions({DateTime? from, DateTime? to, String? type});
}
