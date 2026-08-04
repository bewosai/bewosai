import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/report_models.dart';
import '../../domain/usecases/report_usecases.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/report_provider.dart';

class ReportsScreen extends StatefulWidget {
  final int initialTabIndex;
  const ReportsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rp = context.read<ReportProvider>();
      rp.loadDashboard();
      rp.loadProfit();
      rp.loadInventory();
      rp.loadAging();
      rp.loadDayBook(DateTime.now());
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
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Profit & Loss'),
            Tab(text: 'Stock'),
            Tab(text: 'Aging'),
            Tab(text: 'Sales'),
            Tab(text: 'Day Book'),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _ProfitTab(),
          _StockTab(),
          _AgingTab(),
          _SalesTab(),
          _DayBookTab(),
        ],
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
            KpiCard.currency(label: 'Sales (month)', value: d.salesMonth, icon: Icons.point_of_sale, color: AppColors.orange),
            KpiCard.currency(label: 'Expenses (month)', value: d.expensesMonth, icon: Icons.receipt_long_outlined, color: AppColors.error),
            KpiCard.currency(label: 'Net Profit (month)', value: d.profitMonth, icon: Icons.trending_up, color: d.profitMonth >= 0 ? AppColors.success : AppColors.error),
            KpiCard.currency(label: 'COGS (month)', value: d.cogsMonth, icon: Icons.inventory_2_outlined, color: AppColors.navy600),
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
            KpiCard.currency(label: 'Revenue', value: profit.revenue, icon: Icons.attach_money, color: AppColors.orange),
            KpiCard.currency(label: 'COGS', value: profit.cogs, icon: Icons.inventory_2_outlined, color: AppColors.navy600),
            KpiCard.currency(label: 'Gross Profit', value: profit.grossProfit, icon: Icons.trending_up, color: AppColors.info),
            KpiCard.currency(label: 'Expenses', value: profit.expenses, icon: Icons.receipt_long_outlined, color: AppColors.error),
          ],
        ),
        const SizedBox(height: 12),
        AppSectionCard(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(Formatters.currency(profit.netProfit), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: profit.netProfit >= 0 ? AppColors.success : AppColors.error)),
          ]),
          const Divider(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Gross Margin'), Text('${profit.grossMarginPct.toStringAsFixed(1)}%'),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Net Margin'), Text('${profit.netMarginPct.toStringAsFixed(1)}%'),
          ]),
        ]),
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
            KpiCard(label: 'Total Products', value: '${inv.totalProducts}', icon: Icons.inventory_2_outlined, color: AppColors.orange),
            KpiCard(label: 'Low Stock', value: '${inv.lowStockCount}', icon: Icons.warning_amber_rounded, color: AppColors.warning),
            KpiCard(label: 'Out of Stock', value: '${inv.outOfStockCount}', icon: Icons.remove_shopping_cart_outlined, color: AppColors.error),
            KpiCard.currency(label: 'Stock Value', value: inv.stockValue, icon: Icons.account_balance_wallet_outlined, color: AppColors.info),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Low Stock Items'),
        const SizedBox(height: 10),
        if (inv.lowStockItems.isEmpty)
          AppSectionCard(children: [Text('No low stock items', style: TextStyle(color: AppColors.textSecondary))])
        else
          AppSectionCard(
            children: inv.lowStockItems.map((item) {
              final isLast = item == inv.lowStockItems.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${item['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${item['stock_quantity'] ?? 0}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
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
        AppSectionCard(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Receivable', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(Formatters.currency(aging.totalReceivable), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.warning)),
          ]),
        ]),
        const SizedBox(height: 16),
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard.currency(label: aging.current.label.isEmpty ? '0-30 days' : aging.current.label, value: aging.current.total, icon: Icons.circle, color: AppColors.success, subLabel: '${aging.current.count} invoices'),
            KpiCard.currency(label: aging.days31to60.label.isEmpty ? '31-60 days' : aging.days31to60.label, value: aging.days31to60.total, icon: Icons.circle, color: AppColors.warning, subLabel: '${aging.days31to60.count} invoices'),
            KpiCard.currency(label: aging.days61to90.label.isEmpty ? '61-90 days' : aging.days61to90.label, value: aging.days61to90.total, icon: Icons.circle, color: AppColors.orange, subLabel: '${aging.days61to90.count} invoices'),
            KpiCard.currency(label: aging.over90.label.isEmpty ? '90+ days' : aging.over90.label, value: aging.over90.total, icon: Icons.circle, color: AppColors.error, subLabel: '${aging.over90.count} invoices'),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Top Overdue Customers'),
        const SizedBox(height: 10),
        if (aging.topDebtors.isEmpty)
          AppSectionCard(children: [Text('No overdue customers', style: TextStyle(color: AppColors.textSecondary))])
        else
          AppSectionCard(
            children: aging.topDebtors.map((d) {
              final isLast = d == aging.topDebtors.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${d['customer__name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(Formatters.currency(Formatters.toDouble(d['total_due'])), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
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
            KpiCard.currency(label: 'Total Sales', value: r.totalSales, icon: Icons.point_of_sale, color: AppColors.orange),
            KpiCard.currency(label: 'Total Paid', value: r.totalPaid, icon: Icons.payments_outlined, color: AppColors.success),
            KpiCard.currency(label: 'Total Due', value: r.totalDue, icon: Icons.call_received, color: AppColors.warning),
            KpiCard(label: 'Invoices', value: '${r.count}', icon: Icons.receipt_long_outlined, color: AppColors.info),
          ],
        ),
        const SizedBox(height: 20),
        Text('Last 30 days', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null) {
              setState(() => _date = picked);
              reportProvider.loadDayBook(picked);
            }
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Date'), child: Text(Formatters.date(_date))),
        ),
        const SizedBox(height: 16),
        if (d == null)
          const LoadingView()
        else ...[
          Row(children: [
            Expanded(child: _stat('Cash In', d.totalIn, AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Cash Out', d.totalOut, AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Net Cash', d.netCash, d.netCash >= 0 ? AppColors.success : AppColors.error)),
          ]),
          const SizedBox(height: 20),
          if (d.entries.isEmpty)
            const EmptyState(icon: Icons.book_outlined, title: 'No transactions on this date')
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
                            Row(children: [StatusBadge(label: e.type, color: AppColors.navy500), const SizedBox(width: 6), Text(e.ref, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
                            if (e.party.isNotEmpty) Text(e.party, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (e.debit > 0) Text('+${Formatters.currency(e.debit)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                      if (e.credit > 0) Text('-${Formatters.currency(e.credit)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
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

class _BarChart extends StatelessWidget {
  final List<MonthlyPoint> points;
  const _BarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: 160, child: Center(child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary))));
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
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(points[i].label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)));
                },
              ),
            ),
          ),
          barGroups: List.generate(points.length, (i) {
            final m = points[i];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: m.revenue, color: AppColors.orange, width: 6, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: m.expenses, color: AppColors.navy300, width: 6, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: m.netProfit, color: AppColors.success, width: 6, borderRadius: BorderRadius.circular(3)),
            ]);
          }),
        ),
      ),
    );
  }
}
