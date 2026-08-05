import '../../data/models/report_models.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../repositories/report_repository.dart';

class ReportUseCases {
  final ReportRepository _repository;
  ReportUseCases([ReportRepository? repository]) : _repository = repository ?? ReportRepositoryImpl();

  Future<DashboardSummary> getDashboard() => _repository.dashboard();
  Future<List<MonthlyPoint>> getMonthly() => _repository.monthly();
  Future<SalesReport> getSalesReport({DateTime? from, DateTime? to}) => _repository.salesReport(from: from, to: to);
  Future<ProfitReport> getProfitReport({DateTime? from, DateTime? to}) => _repository.profitReport(from: from, to: to);
  Future<InventoryReport> getInventoryReport() => _repository.inventoryReport();
  Future<ReceivableAging> getReceivableAging() => _repository.receivableAging();
  Future<DayBook> getDayBook(DateTime date) => _repository.dayBook(date);
  Future<CashFlow> getCashFlow({DateTime? from, DateTime? to}) => _repository.cashFlow(from: from, to: to);
  Future<ExpenseReport> getExpenseReport({DateTime? from, DateTime? to}) => _repository.expenseReport(from: from, to: to);
  Future<StockReport> getStockReport() => _repository.stockReport();
  Future<CashInHand> getCashInHand({DateTime? from, DateTime? to}) => _repository.cashInHand(from: from, to: to);
  Future<List<BankAccountSummary>> getBankAccounts() => _repository.bankAccounts();
  Future<BankStatement> getBankStatement(int accountId, {DateTime? from, DateTime? to}) =>
      _repository.bankStatement(accountId, from: from, to: to);
  Future<AllTransactionsReport> getAllTransactions({DateTime? from, DateTime? to, String? type}) =>
      _repository.allTransactions(from: from, to: to, type: type);
}
