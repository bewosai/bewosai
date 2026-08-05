import '../../../../core/utils/formatters.dart';
import '../../../sales/data/models/sale_model.dart';

class TopItem {
  final String productName;
  final double totalQty;
  final double totalRevenue;
  TopItem({required this.productName, required this.totalQty, required this.totalRevenue});
  factory TopItem.fromJson(Map<String, dynamic> json) => TopItem(
        productName: json['product_name'] as String? ?? '',
        totalQty: Formatters.toDouble(json['total_qty']),
        totalRevenue: Formatters.toDouble(json['total_revenue']),
      );
}

class DashboardSummary {
  final double salesToday;
  final double salesMonth;
  final double purchasesToday;
  final double expensesToday;
  final double expensesMonth;
  final double collectionToday;
  final double totalReceivable;
  final double totalPayable;
  final double cashBalance;
  final int lowStockCount;
  final double cogsMonth;
  final double grossProfitMonth;
  final double profitMonth;
  final List<TopItem> topItems;
  final List<Sale> recentSales;

  DashboardSummary({
    required this.salesToday,
    required this.salesMonth,
    required this.purchasesToday,
    required this.expensesToday,
    required this.expensesMonth,
    required this.collectionToday,
    required this.totalReceivable,
    required this.totalPayable,
    required this.cashBalance,
    required this.lowStockCount,
    required this.cogsMonth,
    required this.grossProfitMonth,
    required this.profitMonth,
    required this.topItems,
    required this.recentSales,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        salesToday: Formatters.toDouble(json['sales_today']),
        salesMonth: Formatters.toDouble(json['sales_month']),
        purchasesToday: Formatters.toDouble(json['purchases_today']),
        expensesToday: Formatters.toDouble(json['expenses_today']),
        expensesMonth: Formatters.toDouble(json['expenses_month']),
        collectionToday: Formatters.toDouble(json['collection_today']),
        totalReceivable: Formatters.toDouble(json['total_receivable']),
        totalPayable: Formatters.toDouble(json['total_payable']),
        cashBalance: Formatters.toDouble(json['cash_balance']),
        lowStockCount: json['low_stock_count'] as int? ?? 0,
        cogsMonth: Formatters.toDouble(json['cogs_month']),
        grossProfitMonth: Formatters.toDouble(json['gross_profit_month']),
        profitMonth: Formatters.toDouble(json['profit_month']),
        topItems: (json['top_items'] as List? ?? []).map((e) => TopItem.fromJson(e as Map<String, dynamic>)).toList(),
        recentSales: (json['recent_sales'] as List? ?? []).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class MonthlyPoint {
  final int year;
  final int month;
  final double revenue;
  final double cogs;
  final double expenses;
  final double grossProfit;
  final double netProfit;

  MonthlyPoint({
    required this.year,
    required this.month,
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.grossProfit,
    required this.netProfit,
  });

  factory MonthlyPoint.fromJson(Map<String, dynamic> json) => MonthlyPoint(
        year: json['year'] as int? ?? 0,
        month: json['month'] as int? ?? 0,
        revenue: Formatters.toDouble(json['revenue']),
        cogs: Formatters.toDouble(json['cogs']),
        expenses: Formatters.toDouble(json['expenses']),
        grossProfit: Formatters.toDouble(json['gross_profit']),
        netProfit: Formatters.toDouble(json['net_profit'] ?? json['profit']),
      );

  String get label => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][month.clamp(0, 12)];
}

class SalesReport {
  final double totalSales;
  final double totalPaid;
  final double totalDue;
  final int count;
  final List<Map<String, dynamic>> daily;

  SalesReport({required this.totalSales, required this.totalPaid, required this.totalDue, required this.count, required this.daily});

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return SalesReport(
      totalSales: Formatters.toDouble(summary['total_sales']),
      totalPaid: Formatters.toDouble(summary['total_paid']),
      totalDue: Formatters.toDouble(summary['total_due']),
      count: summary['count'] as int? ?? 0,
      daily: (json['daily'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

class ProfitReport {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double grossMarginPct;
  final double netMarginPct;
  final List<MonthlyPoint> monthly;

  ProfitReport({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.grossMarginPct,
    required this.netMarginPct,
    required this.monthly,
  });

  factory ProfitReport.fromJson(Map<String, dynamic> json) => ProfitReport(
        revenue: Formatters.toDouble(json['revenue']),
        cogs: Formatters.toDouble(json['cogs']),
        grossProfit: Formatters.toDouble(json['gross_profit']),
        expenses: Formatters.toDouble(json['expenses']),
        netProfit: Formatters.toDouble(json['net_profit'] ?? json['profit']),
        grossMarginPct: Formatters.toDouble(json['gross_margin_pct']),
        netMarginPct: Formatters.toDouble(json['net_margin_pct']),
        monthly: (json['monthly'] as List? ?? []).map((e) => MonthlyPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class InventoryReport {
  final int totalProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final double stockValue;
  final List<Map<String, dynamic>> lowStockItems;

  InventoryReport({
    required this.totalProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockValue,
    required this.lowStockItems,
  });

  factory InventoryReport.fromJson(Map<String, dynamic> json) => InventoryReport(
        totalProducts: json['total_products'] as int? ?? 0,
        lowStockCount: json['low_stock_count'] as int? ?? 0,
        outOfStockCount: json['out_of_stock_count'] as int? ?? 0,
        stockValue: Formatters.toDouble(json['stock_value']),
        lowStockItems: (json['low_stock_items'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
}

class AgingBucket {
  final int count;
  final double total;
  final String label;
  AgingBucket({required this.count, required this.total, required this.label});
  factory AgingBucket.fromJson(Map<String, dynamic> json) => AgingBucket(
        count: json['count'] as int? ?? 0,
        total: Formatters.toDouble(json['total']),
        label: json['label'] as String? ?? '',
      );
}

class ReceivableAging {
  final double totalReceivable;
  final AgingBucket current;
  final AgingBucket days31to60;
  final AgingBucket days61to90;
  final AgingBucket over90;
  final List<Map<String, dynamic>> topDebtors;

  ReceivableAging({
    required this.totalReceivable,
    required this.current,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
    required this.topDebtors,
  });

  factory ReceivableAging.fromJson(Map<String, dynamic> json) => ReceivableAging(
        totalReceivable: Formatters.toDouble(json['total_receivable']),
        current: AgingBucket.fromJson(json['current'] as Map<String, dynamic>? ?? {}),
        days31to60: AgingBucket.fromJson(json['days31_60'] as Map<String, dynamic>? ?? {}),
        days61to90: AgingBucket.fromJson(json['days61_90'] as Map<String, dynamic>? ?? {}),
        over90: AgingBucket.fromJson(json['over90'] as Map<String, dynamic>? ?? {}),
        topDebtors: (json['top_debtors'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
}

class DayBookEntry {
  final DateTime? date;
  final String type;
  final String ref;
  final String party;
  final double debit;
  final double credit;
  final String method;
  final String note;

  DayBookEntry({
    this.date,
    required this.type,
    required this.ref,
    required this.party,
    required this.debit,
    required this.credit,
    required this.method,
    required this.note,
  });

  factory DayBookEntry.fromJson(Map<String, dynamic> json) => DayBookEntry(
        date: Formatters.parseDate(json['date'] as String?),
        type: json['type'] as String? ?? '',
        ref: json['ref']?.toString() ?? '',
        party: json['party']?.toString() ?? '',
        debit: Formatters.toDouble(json['debit']),
        credit: Formatters.toDouble(json['credit']),
        method: json['method'] as String? ?? '',
        note: json['note']?.toString() ?? '',
      );
}

class DayBook {
  final DateTime? date;
  final List<DayBookEntry> entries;
  final double totalIn;
  final double totalOut;
  final double netCash;

  DayBook({this.date, required this.entries, required this.totalIn, required this.totalOut, required this.netCash});

  factory DayBook.fromJson(Map<String, dynamic> json) => DayBook(
        date: Formatters.parseDate(json['date'] as String?),
        entries: (json['entries'] as List? ?? []).map((e) => DayBookEntry.fromJson(e as Map<String, dynamic>)).toList(),
        totalIn: Formatters.toDouble(json['total_in']),
        totalOut: Formatters.toDouble(json['total_out']),
        netCash: Formatters.toDouble(json['net_cash']),
      );
}

class CashFlow {
  final double cashInSales;
  final double cashInPartyPayments;
  final double cashInTotal;
  final double cashOutExpenses;
  final double cashOutPurchases;
  final double cashOutPartyPayments;
  final double cashOutTotal;
  final double netCashFlow;

  CashFlow({
    required this.cashInSales,
    required this.cashInPartyPayments,
    required this.cashInTotal,
    required this.cashOutExpenses,
    required this.cashOutPurchases,
    required this.cashOutPartyPayments,
    required this.cashOutTotal,
    required this.netCashFlow,
  });

  factory CashFlow.fromJson(Map<String, dynamic> json) {
    final cashIn = json['cash_in'] as Map<String, dynamic>? ?? {};
    final cashOut = json['cash_out'] as Map<String, dynamic>? ?? {};
    return CashFlow(
      cashInSales: Formatters.toDouble(cashIn['sales_collection']),
      cashInPartyPayments: Formatters.toDouble(cashIn['party_payments']),
      cashInTotal: Formatters.toDouble(cashIn['total']),
      cashOutExpenses: Formatters.toDouble(cashOut['expenses']),
      cashOutPurchases: Formatters.toDouble(cashOut['purchases']),
      cashOutPartyPayments: Formatters.toDouble(cashOut['party_payments']),
      cashOutTotal: Formatters.toDouble(cashOut['total']),
      netCashFlow: Formatters.toDouble(json['net_cash_flow']),
    );
  }
}

class ExpenseReport {
  final double total;
  final List<Map<String, dynamic>> byCategory;
  ExpenseReport({required this.total, required this.byCategory});
  factory ExpenseReport.fromJson(Map<String, dynamic> json) => ExpenseReport(
        total: Formatters.toDouble(json['total']),
        byCategory: (json['by_category'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
}

class StockReportItem {
  final int id;
  final String name;
  final String category;
  final String unit;
  final double stockQuantity;
  final double purchasePrice;
  final double salePrice;
  final double stockValue;
  final bool isLowStock;

  StockReportItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQuantity,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockValue,
    required this.isLowStock,
  });

  factory StockReportItem.fromJson(Map<String, dynamic> json) => StockReportItem(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        stockQuantity: Formatters.toDouble(json['stock_quantity']),
        purchasePrice: Formatters.toDouble(json['purchase_price']),
        salePrice: Formatters.toDouble(json['sale_price']),
        stockValue: Formatters.toDouble(json['stock_value']),
        isLowStock: json['is_low_stock'] as bool? ?? false,
      );
}

class StockReport {
  final List<StockReportItem> items;
  final int totalProducts;
  final double totalQuantity;
  final double totalStockValue;

  StockReport({
    required this.items,
    required this.totalProducts,
    required this.totalQuantity,
    required this.totalStockValue,
  });

  factory StockReport.fromJson(Map<String, dynamic> json) => StockReport(
        items: (json['items'] as List? ?? []).map((e) => StockReportItem.fromJson(e as Map<String, dynamic>)).toList(),
        totalProducts: json['total_products'] as int? ?? 0,
        totalQuantity: Formatters.toDouble(json['total_quantity']),
        totalStockValue: Formatters.toDouble(json['total_stock_value']),
      );
}

class CashHandEntry {
  final DateTime? date;
  final String type;
  final String ref;
  final String party;
  final double debit;
  final double credit;
  final double balance;

  CashHandEntry({
    this.date,
    required this.type,
    required this.ref,
    required this.party,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory CashHandEntry.fromJson(Map<String, dynamic> json) => CashHandEntry(
        date: Formatters.parseDate(json['date'] as String?),
        type: json['type'] as String? ?? '',
        ref: json['ref']?.toString() ?? '',
        party: json['party']?.toString() ?? '',
        debit: Formatters.toDouble(json['debit']),
        credit: Formatters.toDouble(json['credit']),
        balance: Formatters.toDouble(json['balance']),
      );
}

class CashInHand {
  final double openingBalance;
  final List<CashHandEntry> entries;
  final double totalIn;
  final double totalOut;
  final double closingBalance;

  CashInHand({
    required this.openingBalance,
    required this.entries,
    required this.totalIn,
    required this.totalOut,
    required this.closingBalance,
  });

  factory CashInHand.fromJson(Map<String, dynamic> json) => CashInHand(
        openingBalance: Formatters.toDouble(json['opening_balance']),
        entries: (json['entries'] as List? ?? []).map((e) => CashHandEntry.fromJson(e as Map<String, dynamic>)).toList(),
        totalIn: Formatters.toDouble(json['total_in']),
        totalOut: Formatters.toDouble(json['total_out']),
        closingBalance: Formatters.toDouble(json['closing_balance']),
      );
}

class BankAccountSummary {
  final int id;
  final String accountName;
  final String bankName;
  final String accountType;
  final double openingBalance;
  final double balance;

  BankAccountSummary({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountType,
    required this.openingBalance,
    required this.balance,
  });

  factory BankAccountSummary.fromJson(Map<String, dynamic> json) => BankAccountSummary(
        id: json['id'] as int? ?? 0,
        accountName: json['account_name'] as String? ?? '',
        bankName: json['bank_name'] as String? ?? '',
        accountType: json['account_type'] as String? ?? '',
        openingBalance: Formatters.toDouble(json['opening_balance']),
        balance: Formatters.toDouble(json['balance']),
      );
}

class BankStatementEntry {
  final DateTime? date;
  final String type;
  final String description;
  final String reference;
  final double debit;
  final double credit;
  final double balance;

  BankStatementEntry({
    this.date,
    required this.type,
    required this.description,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory BankStatementEntry.fromJson(Map<String, dynamic> json) => BankStatementEntry(
        date: Formatters.parseDate(json['date'] as String?),
        type: json['type'] as String? ?? '',
        description: json['description'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        debit: Formatters.toDouble(json['debit']),
        credit: Formatters.toDouble(json['credit']),
        balance: Formatters.toDouble(json['balance']),
      );
}

class BankStatement {
  final BankAccountSummary account;
  final double openingBalance;
  final List<BankStatementEntry> entries;
  final double totalCredit;
  final double totalDebit;
  final double closingBalance;

  BankStatement({
    required this.account,
    required this.openingBalance,
    required this.entries,
    required this.totalCredit,
    required this.totalDebit,
    required this.closingBalance,
  });

  factory BankStatement.fromJson(Map<String, dynamic> json) => BankStatement(
        account: BankAccountSummary.fromJson(json['account'] as Map<String, dynamic>? ?? {}),
        openingBalance: Formatters.toDouble(json['opening_balance']),
        entries: (json['entries'] as List? ?? []).map((e) => BankStatementEntry.fromJson(e as Map<String, dynamic>)).toList(),
        totalCredit: Formatters.toDouble(json['total_credit']),
        totalDebit: Formatters.toDouble(json['total_debit']),
        closingBalance: Formatters.toDouble(json['closing_balance']),
      );
}

class AllTransactionEntry {
  final DateTime? date;
  final String type;
  final String ref;
  final String party;
  final double amount;
  final double paid;
  final double due;
  final String method;

  AllTransactionEntry({
    this.date,
    required this.type,
    required this.ref,
    required this.party,
    required this.amount,
    required this.paid,
    required this.due,
    required this.method,
  });

  factory AllTransactionEntry.fromJson(Map<String, dynamic> json) => AllTransactionEntry(
        date: Formatters.parseDate(json['date'] as String?),
        type: json['type'] as String? ?? '',
        ref: json['ref']?.toString() ?? '',
        party: json['party']?.toString() ?? '',
        amount: Formatters.toDouble(json['amount']),
        paid: Formatters.toDouble(json['paid']),
        due: Formatters.toDouble(json['due']),
        method: json['method'] as String? ?? '',
      );
}

class AllTransactionsReport {
  final List<AllTransactionEntry> entries;
  final int count;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;

  AllTransactionsReport({
    required this.entries,
    required this.count,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
  });

  factory AllTransactionsReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return AllTransactionsReport(
      entries: (json['entries'] as List? ?? []).map((e) => AllTransactionEntry.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? 0,
      totalSales: Formatters.toDouble(summary['total_sales']),
      totalPurchases: Formatters.toDouble(summary['total_purchases']),
      totalExpenses: Formatters.toDouble(summary['total_expenses']),
    );
  }
}
