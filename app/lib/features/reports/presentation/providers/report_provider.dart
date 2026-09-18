import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/report_models.dart';
import '../../domain/usecases/report_usecases.dart';
import '../../../../core/calendar/nepal_time.dart';

class ReportProvider extends ChangeNotifier {
  final _useCases = ReportUseCases();

  DashboardSummary? dashboard;
  List<MonthlyPoint> monthly = [];
  ProfitReport? profit;
  InventoryReport? inventory;
  ReceivableAging? aging;
  DayBook? dayBook;
  CashFlow? cashFlow;
  List<DayBook> weeklyCashflow = [];
  ExpenseReport? expenseReport;
  StockReport? stockReport;
  CashInHand? cashInHand;
  List<BankAccountSummary> bankAccounts = [];
  BankStatement? bankStatement;
  AllTransactionsReport? allTransactions;

  bool isLoading = false;
  String? error;

  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();
    // The monthly series is behind the stricter "reports" feature/staff
    // permission (the summary isn't), and the dashboard doesn't depend on it
    // — so a refusal there must not blank the whole dashboard with "Could not
    // load". Started together with the summary, but its failure is swallowed.
    final monthlyFuture = _useCases.getMonthly().then<List<MonthlyPoint>>(
      (v) => v,
      onError: (_) => <MonthlyPoint>[],
    );
    try {
      dashboard = await _useCases.getDashboard();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    monthly = await monthlyFuture;
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadProfit({DateTime? from, DateTime? to}) async {
    try {
      profit = await _useCases.getProfitReport(from: from, to: to);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadInventory() async {
    try {
      inventory = await _useCases.getInventoryReport();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAging() async {
    try {
      aging = await _useCases.getReceivableAging();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadDayBook(DateTime date) async {
    try {
      dayBook = await _useCases.getDayBook(date);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCashFlow({DateTime? from, DateTime? to}) async {
    try {
      cashFlow = await _useCases.getCashFlow(from: from, to: to);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadExpenseReport({DateTime? from, DateTime? to}) async {
    try {
      expenseReport = await _useCases.getExpenseReport(from: from, to: to);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadStockReport() async {
    try {
      stockReport = await _useCases.getStockReport();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCashInHand({DateTime? from, DateTime? to}) async {
    try {
      cashInHand = await _useCases.getCashInHand(from: from, to: to);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadBankAccounts() async {
    try {
      bankAccounts = await _useCases.getBankAccounts();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadBankStatement(int accountId, {DateTime? from, DateTime? to}) async {
    bankStatement = null;
    notifyListeners();
    try {
      bankStatement = await _useCases.getBankStatement(accountId, from: from, to: to);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAllTransactions({DateTime? from, DateTime? to, String? type}) async {
    try {
      allTransactions = await _useCases.getAllTransactions(from: from, to: to, type: type);
      notifyListeners();
    } catch (_) {}
  }

  /// Builds a 7-day cashflow series by fetching the day-book for each of the
  /// last 7 days (oldest first) — there's no dedicated ranged endpoint, so
  /// this composes it client-side from the existing single-day one.
  Future<void> loadWeeklyCashflow() async {
    try {
      final today = NepalTime.now();
      final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
      final results = await Future.wait(days.map((d) => _useCases.getDayBook(d)));
      weeklyCashflow = results;
      notifyListeners();
    } catch (_) {}
  }
}
