import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../parties/presentation/providers/party_provider.dart';
import '../../data/models/report_models.dart';
import '../../domain/usecases/report_usecases.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/report_provider.dart';

/// Tab order — indices referenced by ReportsHubScreen's Popular Reports tiles
/// and Browse-All-Reports categories, so keep this list and that screen in sync.
const kReportTabs = [
  'Overview', 'Profit & Loss', 'Stock', 'Aging', 'Sales', 'Expenses',
  'Day Book', 'All Transactions', 'Party Statement', 'Cash In Hand', 'Bank Statement',
];

class ReportsScreen extends StatefulWidget {
  final int initialTabIndex;
  const ReportsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: kReportTabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rp = context.read<ReportProvider>();
      rp.loadDashboard();
      rp.loadProfit();
      rp.loadInventory();
      rp.loadStockReport();
      rp.loadAging();
      rp.loadDayBook(DateTime.now());
      rp.loadExpenseReport();
      rp.loadCashInHand();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [HomeLogoButton()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.orange,
          tabs: kReportTabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: TabBarView(
          controller: _tabController,
          children: const [
            _OverviewTab(),
            _ProfitTab(),
            _StockTab(),
            _AgingTab(),
            _SalesTab(),
            _ExpensesTab(),
            _DayBookTab(),
            _AllTransactionsTab(),
            _PartyStatementTab(),
            _CashInHandTab(),
            _BankStatementTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportProvider>();
    final d = rp.dashboard;
    if (d == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard.currency(
              label: 'Sales (month)',
              value: d.salesMonth,
              icon: Icons.point_of_sale,
              color: AppColors.orange,
            ),
            KpiCard.currency(
              label: 'Expenses (month)',
              value: d.expensesMonth,
              icon: Icons.receipt_long_outlined,
              color: AppColors.error,
            ),
            KpiCard.currency(
              label: 'Net Profit (month)',
              value: d.profitMonth,
              icon: Icons.trending_up,
              color: d.profitMonth >= 0 ? AppColors.success : AppColors.error,
            ),
            KpiCard.currency(
              label: 'COGS (month)',
              value: d.cogsMonth,
              icon: Icons.inventory_2_outlined,
              color: AppColors.navy600,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Revenue vs Expenses (12 months)'),
        const SizedBox(height: 10),
        AppSectionCard(children: [_BarChart(points: rp.monthly)]),
      ],
    );
  }
}

class _ProfitTab extends StatelessWidget {
  const _ProfitTab();

  @override
  Widget build(BuildContext context) {
    final profit = context.watch<ReportProvider>().profit;
    if (profit == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard.currency(
              label: 'Revenue',
              value: profit.revenue,
              icon: Icons.attach_money,
              color: AppColors.orange,
            ),
            KpiCard.currency(
              label: 'COGS',
              value: profit.cogs,
              icon: Icons.inventory_2_outlined,
              color: AppColors.navy600,
            ),
            KpiCard.currency(
              label: 'Gross Profit',
              value: profit.grossProfit,
              icon: Icons.trending_up,
              color: AppColors.info,
            ),
            KpiCard.currency(
              label: 'Expenses',
              value: profit.expenses,
              icon: Icons.receipt_long_outlined,
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Profit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  Formatters.currency(profit.netProfit),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: profit.netProfit >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gross Margin'),
                Text('${profit.grossMarginPct.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Margin'),
                Text('${profit.netMarginPct.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Monthly Trend'),
        const SizedBox(height: 10),
        AppSectionCard(children: [_BarChart(points: profit.monthly)]),
      ],
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<ReportProvider>().inventory;
    if (inv == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard(
              label: 'Total Products',
              value: '${inv.totalProducts}',
              icon: Icons.inventory_2_outlined,
              color: AppColors.orange,
            ),
            KpiCard(
              label: 'Low Stock',
              value: '${inv.lowStockCount}',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
            KpiCard(
              label: 'Out of Stock',
              value: '${inv.outOfStockCount}',
              icon: Icons.remove_shopping_cart_outlined,
              color: AppColors.error,
            ),
            KpiCard.currency(
              label: 'Stock Value',
              value: inv.stockValue,
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Low Stock Items'),
        const SizedBox(height: 10),
        if (inv.lowStockItems.isEmpty)
          AppSectionCard(
            children: [
              Text(
                'No low stock items',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          )
        else
          AppSectionCard(
            children: inv.lowStockItems.map((item) {
              final isLast = item == inv.lowStockItems.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${item['stock_quantity'] ?? 0}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'All Products'),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final stock = context.watch<ReportProvider>().stockReport;
          if (stock == null) return const LoadingView();
          if (stock.items.isEmpty) {
            return AppSectionCard(
              children: [Text('No products found', style: TextStyle(color: AppColors.textSecondary))],
            );
          }
          return AppSectionCard(
            children: [
              for (final p in stock.items)
                Padding(
                  padding: EdgeInsets.only(bottom: p == stock.items.last ? 0 : 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (p.isLowStock) ...[
                                const SizedBox(width: 6),
                                const StatusBadge(label: 'Low', color: AppColors.warning),
                              ],
                            ]),
                            Text('${p.stockQuantity} ${p.unit} · ${p.category}',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(Formatters.currency(p.stockValue),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.info)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total (${stock.totalProducts} products)', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(Formatters.currency(stock.totalStockValue),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.info)),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _AgingTab extends StatelessWidget {
  const _AgingTab();

  @override
  Widget build(BuildContext context) {
    final aging = context.watch<ReportProvider>().aging;
    if (aging == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppSectionCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Receivable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  Formatters.currency(aging.totalReceivable),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard.currency(
              label: aging.current.label.isEmpty
                  ? '0-30 days'
                  : aging.current.label,
              value: aging.current.total,
              icon: Icons.circle,
              color: AppColors.success,
              subLabel: '${aging.current.count} invoices',
            ),
            KpiCard.currency(
              label: aging.days31to60.label.isEmpty
                  ? '31-60 days'
                  : aging.days31to60.label,
              value: aging.days31to60.total,
              icon: Icons.circle,
              color: AppColors.warning,
              subLabel: '${aging.days31to60.count} invoices',
            ),
            KpiCard.currency(
              label: aging.days61to90.label.isEmpty
                  ? '61-90 days'
                  : aging.days61to90.label,
              value: aging.days61to90.total,
              icon: Icons.circle,
              color: AppColors.orange,
              subLabel: '${aging.days61to90.count} invoices',
            ),
            KpiCard.currency(
              label: aging.over90.label.isEmpty
                  ? '90+ days'
                  : aging.over90.label,
              value: aging.over90.total,
              icon: Icons.circle,
              color: AppColors.error,
              subLabel: '${aging.over90.count} invoices',
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Top Overdue Customers'),
        const SizedBox(height: 10),
        if (aging.topDebtors.isEmpty)
          AppSectionCard(
            children: [
              Text(
                'No overdue customers',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          )
        else
          AppSectionCard(
            children: aging.topDebtors.map((d) {
              final isLast = d == aging.topDebtors.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${d['customer__name'] ?? 'Unknown'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      Formatters.currency(Formatters.toDouble(d['total_due'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _SalesTab extends StatefulWidget {
  const _SalesTab();
  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  final _useCases = ReportUseCases();
  SalesReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _useCases.getSalesReport();
    if (mounted) setState(() => _report = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    if (r == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard.currency(
              label: 'Total Sales',
              value: r.totalSales,
              icon: Icons.point_of_sale,
              color: AppColors.orange,
            ),
            KpiCard.currency(
              label: 'Total Paid',
              value: r.totalPaid,
              icon: Icons.payments_outlined,
              color: AppColors.success,
            ),
            KpiCard.currency(
              label: 'Total Due',
              value: r.totalDue,
              icon: Icons.call_received,
              color: AppColors.warning,
            ),
            KpiCard(
              label: 'Invoices',
              value: '${r.count}',
              icon: Icons.receipt_long_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Last 30 days',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _DayBookTab extends StatefulWidget {
  const _DayBookTab();
  @override
  State<_DayBookTab> createState() => _DayBookTabState();
}

class _DayBookTabState extends State<_DayBookTab> {
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportProvider>();
    final d = rp.dayBook;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: () async {
            final reportProvider = context.read<ReportProvider>();
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _date = picked);
              reportProvider.loadDayBook(picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date'),
            child: Text(Formatters.date(_date)),
          ),
        ),
        const SizedBox(height: 16),
        if (d == null)
          const LoadingView()
        else ...[
          Row(
            children: [
              Expanded(child: _stat('Cash In', d.totalIn, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Cash Out', d.totalOut, AppColors.error)),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  'Net Cash',
                  d.netCash,
                  d.netCash >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (d.entries.isEmpty)
            const EmptyState(
              icon: Icons.book_outlined,
              title: 'No transactions on this date',
            )
          else
            AppSectionCard(
              children: d.entries.map((e) {
                final isLast = e == d.entries.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StatusBadge(
                                  label: e.type,
                                  color: AppColors.navy500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  e.ref,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (e.party.isNotEmpty)
                              Text(
                                e.party,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (e.debit > 0)
                        Text(
                          '+${Formatters.currency(e.debit)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (e.credit > 0)
                        Text(
                          '-${Formatters.currency(e.credit)}',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MonthlyPoint> points;
  const _BarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No data yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    double maxY = 0;
    for (final m in points) {
      if (m.revenue > maxY) maxY = m.revenue;
      if (m.expenses > maxY) maxY = m.expenses;
    }
    maxY = maxY <= 0 ? 100 : maxY * 1.2;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(points.length, (i) {
            final m = points[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: m.revenue,
                  color: AppColors.orange,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: m.expenses,
                  color: AppColors.navy300,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: m.netProfit,
                  color: AppColors.success,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportProvider>().expenseReport;
    if (report == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppSectionCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Expenses', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(Formatters.currency(report.total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.error)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'By Category'),
        const SizedBox(height: 10),
        if (report.byCategory.isEmpty)
          AppSectionCard(children: [Text('No expenses in the last 30 days', style: TextStyle(color: AppColors.textSecondary))])
        else
          AppSectionCard(
            children: report.byCategory.map((c) {
              final isLast = c == report.byCategory.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${c['category__name'] ?? 'Uncategorized'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(Formatters.currency(Formatters.toDouble(c['total'])),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _AllTransactionsTab extends StatefulWidget {
  const _AllTransactionsTab();
  @override
  State<_AllTransactionsTab> createState() => _AllTransactionsTabState();
}

class _AllTransactionsTabState extends State<_AllTransactionsTab> {
  String? _type;

  static const _filters = [
    (null, 'All'),
    ('SALE', 'Sales'),
    ('PURCHASE', 'Purchases'),
    ('EXPENSE', 'Expenses'),
    ('PAYMENT', 'Payments'),
    ('BANK', 'Bank'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadAllTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportProvider>().allTransactions;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _filters.map((f) {
            return AppFilterChip(
              label: f.$2,
              selected: _type == f.$1,
              onTap: () {
                setState(() => _type = f.$1);
                context.read<ReportProvider>().loadAllTransactions(type: f.$1);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (report == null)
          const LoadingView()
        else if (report.entries.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions in range')
        else
          AppSectionCard(
            children: report.entries.map((e) {
              final isLast = e == report.entries.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            StatusBadge(label: e.type, color: AppColors.navy500),
                            const SizedBox(width: 6),
                            Flexible(child: Text(e.ref, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ]),
                          if (e.party.isNotEmpty)
                            Text(e.party, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(Formatters.currency(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _PartyStatementTab extends StatefulWidget {
  const _PartyStatementTab();
  @override
  State<_PartyStatementTab> createState() => _PartyStatementTabState();
}

class _PartyStatementTabState extends State<_PartyStatementTab> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = context.read<PartyProvider>();
      if (pp.parties.isEmpty) pp.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PartyProvider>();
    final filtered = pp.parties.where((p) => p.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchField(hint: 'Search parties…', onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: pp.isLoading
              ? const LoadingView()
              : filtered.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, title: 'No parties found')
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(p.partyType),
                          trailing: Text(
                            Formatters.currency(p.balance.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: p.balance > 0 ? AppColors.error : p.balance < 0 ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => context.push('/party-ledger/${p.id}'),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CashInHandTab extends StatelessWidget {
  const _CashInHandTab();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<ReportProvider>().cashInHand;
    if (d == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _stat('Opening', d.openingBalance, AppColors.navy600)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Cash In', d.totalIn, AppColors.success)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _stat('Cash Out', d.totalOut, AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Closing', d.closingBalance, d.closingBalance >= 0 ? AppColors.success : AppColors.error)),
          ],
        ),
        const SizedBox(height: 20),
        if (d.entries.isEmpty)
          const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No cash transactions in range')
        else
          AppSectionCard(
            children: d.entries.map((e) {
              final isLast = e == d.entries.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            StatusBadge(label: e.type, color: AppColors.navy500),
                            const SizedBox(width: 6),
                            Flexible(child: Text(e.party, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (e.debit > 0) Text('+${Formatters.currency(e.debit)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        if (e.credit > 0) Text('-${Formatters.currency(e.credit)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                        Text('Bal: ${Formatters.currency(e.balance)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(Formatters.currency(value), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BankStatementTab extends StatefulWidget {
  const _BankStatementTab();
  @override
  State<_BankStatementTab> createState() => _BankStatementTabState();
}

class _BankStatementTabState extends State<_BankStatementTab> {
  BankAccountSummary? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadBankAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportProvider>();

    if (_selected == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Select an Account'),
          const SizedBox(height: 10),
          if (rp.bankAccounts.isEmpty)
            const EmptyState(icon: Icons.account_balance_outlined, title: 'No bank accounts found')
          else
            AppSectionCard(
              children: rp.bankAccounts.map((a) {
                final isLast = a == rp.bankAccounts.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selected = a);
                      context.read<ReportProvider>().loadBankStatement(a.id);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppColors.navy50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.navy600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.accountName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(a.bankName.isEmpty ? a.accountType : a.bankName,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(Formatters.currency(a.balance), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      );
    }

    final s = rp.bankStatement;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: () => setState(() => _selected = null),
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Back to accounts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (s == null)
          const LoadingView()
        else ...[
          Row(
            children: [
              Expanded(child: _stat('Opening', s.openingBalance, AppColors.navy600)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Closing', s.closingBalance, s.closingBalance >= 0 ? AppColors.success : AppColors.error)),
            ],
          ),
          const SizedBox(height: 20),
          if (s.entries.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions in range')
          else
            AppSectionCard(
              children: s.entries.map((e) {
                final isLast = e == s.entries.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(label: e.type, color: AppColors.navy500),
                            if (e.description.isNotEmpty)
                              Text(e.description, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (e.credit > 0) Text('+${Formatters.currency(e.credit)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                          if (e.debit > 0) Text('-${Formatters.currency(e.debit)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                          Text('Bal: ${Formatters.currency(e.balance)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(Formatters.currency(value), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
