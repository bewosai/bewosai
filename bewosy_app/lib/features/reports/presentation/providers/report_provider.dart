import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/report_models.dart';
import '../../domain/usecases/report_usecases.dart';

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

  bool isLoading = false;
  String? error;

  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_useCases.getDashboard(), _useCases.getMonthly()]);
      dashboard = results[0] as DashboardSummary;
      monthly = results[1] as List<MonthlyPoint>;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
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

  /// Builds a 7-day cashflow series by fetching the day-book for each of the
  /// last 7 days (oldest first) — there's no dedicated ranged endpoint, so
  /// this composes it client-side from the existing single-day one.
  Future<void> loadWeeklyCashflow() async {
    try {
      final today = DateTime.now();
      final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
      final results = await Future.wait(days.map((d) => _useCases.getDayBook(d)));
      weeklyCashflow = results;
      notifyListeners();
    } catch (_) {}
  }
}
