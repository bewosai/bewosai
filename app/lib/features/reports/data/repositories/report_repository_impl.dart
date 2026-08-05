import '../../domain/repositories/report_repository.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportService _service;
  ReportRepositoryImpl([ReportService? service]) : _service = service ?? ReportService();

  @override
  Future<DashboardSummary> dashboard() => _service.dashboard();
  @override
  Future<List<MonthlyPoint>> monthly() => _service.monthly();
  @override
  Future<SalesReport> salesReport({DateTime? from, DateTime? to}) => _service.salesReport(from: from, to: to);
  @override
  Future<ProfitReport> profitReport({DateTime? from, DateTime? to}) => _service.profitReport(from: from, to: to);
  @override
  Future<InventoryReport> inventoryReport() => _service.inventoryReport();
  @override
  Future<ReceivableAging> receivableAging() => _service.receivableAging();
  @override
  Future<DayBook> dayBook(DateTime date) => _service.dayBook(date);
  @override
  Future<CashFlow> cashFlow({DateTime? from, DateTime? to}) => _service.cashFlow(from: from, to: to);
  @override
  Future<ExpenseReport> expenseReport({DateTime? from, DateTime? to}) => _service.expenseReport(from: from, to: to);
  @override
  Future<StockReport> stockReport() => _service.stockReport();
  @override
  Future<CashInHand> cashInHand({DateTime? from, DateTime? to}) => _service.cashInHand(from: from, to: to);
  @override
  Future<List<BankAccountSummary>> bankAccounts() => _service.bankAccounts();
  @override
  Future<BankStatement> bankStatement(int accountId, {DateTime? from, DateTime? to}) =>
      _service.bankStatement(accountId, from: from, to: to);
  @override
  Future<AllTransactionsReport> allTransactions({DateTime? from, DateTime? to, String? type}) =>
      _service.allTransactions(from: from, to: to, type: type);
}
