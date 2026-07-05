import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _monthly = [];
  Map _summary = {};
  Map _profit = {};
  Map _inventory = {};
  Map _aging = {};
  Map _dayBook = {};
  bool _loading = true;
  DateTime _dayBookDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final biz = context.read<BusinessProvider>();
    try {
      final dateStr = _dayBookDate.toIso8601String().substring(0, 10);
      final results = await Future.wait([
        biz.getMonthlyReport(),
        biz.getReportSummary(),
        biz.getProfitReport(),
        biz.getInventoryReport(),
        biz.getReceivableAging(),
        biz.getDayBook(date: dateStr),
      ]);
      _monthly   = results[0] as List;
      _summary   = results[1] as Map;
      _profit    = results[2] as Map;
      _inventory = results[3] as Map;
      _aging     = results[4] as Map;
      _dayBook   = results[5] as Map;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('reports'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(monthly: _monthly, summary: _summary, settings: settings),
                _ProfitLossTab(profit: _profit, monthly: _monthly, settings: settings),
                _StockTab(inventory: _inventory, settings: settings),
                _AgingTab(aging: _aging, settings: settings),
                _SalesReportTab(monthly: _monthly, settings: settings),
                _DayBookTab(
                  dayBook: _dayBook,
                  selectedDate: _dayBookDate,
                  settings: settings,
                  onDateChanged: (d) {
                    setState(() => _dayBookDate = d);
                    _fetch();
                  },
                ),
              ],
            ),
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List monthly;
  final Map summary;
  final AppSettings settings;
  const _OverviewTab({required this.monthly, required this.summary, required this.settings});

  @override
  Widget build(BuildContext context) {
    final totalRevenue = monthly.fold<double>(
        0, (s, m) => s + ((m['revenue'] as num?)?.toDouble() ?? 0));
    final totalExpenses = monthly.fold<double>(
        0, (s, m) => s + ((m['expenses'] as num?)?.toDouble() ?? 0));
    final netProfit = totalRevenue - totalExpenses;
    final receivable = (summary['total_receivable'] as num?)?.toDouble() ?? 0;
    final payable    = (summary['total_payable'] as num?)?.toDouble() ?? 0;
    final cashBalance = (summary['cash_balance'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: KpiCard(
            label: settings.t('revenue'),
            value: settings.formatAmount(totalRevenue),
            icon: Icons.trending_up_rounded,
            iconBg: AppColors.infoLight,
            iconColor: AppColors.info,
          )),
          const SizedBox(width: 12),
          Expanded(child: KpiCard(
            label: settings.t('total_expenses'),
            value: settings.formatAmount(totalExpenses),
            icon: Icons.trending_down_rounded,
            iconBg: AppColors.errorLight,
            iconColor: AppColors.error,
          )),
        ]),
        const SizedBox(height: 12),
        // Net profit card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: netProfit >= 0 ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                netProfit >= 0 ? Icons.emoji_events_rounded : Icons.warning_rounded,
                color: netProfit >= 0 ? AppColors.success : AppColors.error,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(netProfit >= 0 ? settings.t('net_profit') : settings.t('loss'),
                    style: const TextStyle(fontSize: 13, color: AppColors.navy500)),
                Text(settings.formatAmount(netProfit.abs()),
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: netProfit >= 0 ? AppColors.success : AppColors.error,
                    )),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 20),
        if (monthly.isNotEmpty) ...[
          const Text('12-Month Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildBarChart(),
          const SizedBox(height: 20),
        ],
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            KpiCard(
              label: settings.t('receivable'),
              value: settings.formatAmount(receivable),
              icon: Icons.arrow_downward_rounded,
              iconBg: AppColors.successLight,
              iconColor: AppColors.success,
            ),
            KpiCard(
              label: settings.t('payable'),
              value: settings.formatAmount(payable),
              icon: Icons.arrow_upward_rounded,
              iconBg: AppColors.errorLight,
              iconColor: AppColors.error,
            ),
            KpiCard(
              label: 'Cash Balance',
              value: settings.formatAmount(cashBalance),
              icon: Icons.account_balance_wallet_rounded,
              iconBg: AppColors.infoLight,
              iconColor: AppColors.info,
            ),
            KpiCard(
              label: 'Profit Margin',
              value: totalRevenue > 0
                  ? '${(netProfit / totalRevenue * 100).toStringAsFixed(1)}%'
                  : '0%',
              icon: Icons.percent_rounded,
              iconBg: const Color(0xFFE9D5FF),
              iconColor: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBarChart() {
    final maxY = monthly
            .map((m) => ((m['revenue'] as num?)?.toDouble() ?? 0))
            .fold(0.0, (a, b) => a > b ? a : b) * 1.2;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY > 0 ? maxY : 100,
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= monthly.length) return const SizedBox();
                  const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                  final mNum = (monthly[idx]['month'] as int? ?? 1) - 1;
                  return Text(months[mNum.clamp(0, 11)],
                      style: const TextStyle(fontSize: 9, color: AppColors.navy500));
                },
              )),
            ),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.navy50, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(monthly.length, (i) {
              final m = monthly[i];
              return BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                    toY: (m['revenue'] as num?)?.toDouble() ?? 0,
                    color: AppColors.info.withOpacity(0.8), width: 6,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                BarChartRodData(
                    toY: (m['expenses'] as num?)?.toDouble() ?? 0,
                    color: AppColors.error.withOpacity(0.8), width: 6,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                BarChartRodData(
                    toY: ((m['profit'] as num?)?.toDouble() ?? 0).clamp(0, double.infinity),
                    color: AppColors.orange, width: 6,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              ]);
            }),
          )),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final item in [
            (AppColors.info, 'Revenue'),
            (AppColors.error, 'Expenses'),
            (AppColors.orange, 'Profit'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: item.$1,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(item.$2,
                    style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ─── Profit & Loss Tab ───────────────────────────────────────────────────────

class _ProfitLossTab extends StatefulWidget {
  final Map profit;
  final List monthly;
  final AppSettings settings;
  const _ProfitLossTab({required this.profit, required this.monthly, required this.settings});
  @override
  State<_ProfitLossTab> createState() => _ProfitLossTabState();
}

class _ProfitLossTabState extends State<_ProfitLossTab> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final p = widget.profit;
    final revenue     = (p['revenue']      as num?)?.toDouble() ?? 0;
    final cogs        = (p['cogs']         as num?)?.toDouble() ?? 0;
    final grossProfit = (p['gross_profit'] as num?)?.toDouble() ?? (revenue - cogs);
    final expenses    = (p['expenses']     as num?)?.toDouble() ?? 0;
    final netProfit   = (p['net_profit']   as num?)?.toDouble() ??
                        (p['profit']       as num?)?.toDouble() ?? 0;
    final grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0.0;
    final netMargin   = revenue > 0 ? (netProfit   / revenue * 100) : 0.0;
    final isProfit    = netProfit >= 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Expanded(child: Text('Profit & Loss Statement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('This Month',
                style: TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),

        _sectionHeader('Income'),
        const SizedBox(height: 8),
        _plRow('Total Revenue', revenue, AppColors.info, Icons.trending_up_rounded, s),

        const SizedBox(height: 16),
        _sectionHeader('Cost of Goods Sold'),
        const SizedBox(height: 8),
        _plRow('COGS', cogs, const Color(0xFF7C3AED), Icons.inventory_2_outlined, s),

        const SizedBox(height: 8),
        _subtotalRow('Gross Profit', grossProfit, grossMargin, s),

        const SizedBox(height: 16),
        _sectionHeader('Operating Expenses'),
        const SizedBox(height: 8),
        _plRow('Total Expenses', expenses, AppColors.error, Icons.receipt_outlined, s),

        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(thickness: 2)),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfit
                  ? [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0.05)]
                  : [AppColors.error.withOpacity(0.15), AppColors.error.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isProfit ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(isProfit ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                color: isProfit ? AppColors.success : AppColors.error, size: 40),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isProfit ? 'Net Profit' : 'Net Loss',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.navy500)),
              Text(s.formatAmount(netProfit.abs()),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                      color: isProfit ? AppColors.success : AppColors.error)),
              Text('Net Margin: ${netMargin.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12,
                      color: isProfit ? AppColors.success : AppColors.error)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        const Text('Monthly Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...widget.monthly.map((m) {
          final rev  = (m['revenue']      as num?)?.toDouble() ?? 0;
          final cg   = (m['cogs']         as num?)?.toDouble() ?? 0;
          final gp   = (m['gross_profit'] as num?)?.toDouble() ?? (rev - cg);
          final exp  = (m['expenses']     as num?)?.toDouble() ?? 0;
          final np   = (m['profit']       as num?)?.toDouble() ?? 0;
          final mNum = (m['month'] as int? ?? 1);
          final yr   = (m['year']  as int? ?? 2024);
          final lbl  = DateFormat('MMM yy').format(DateTime(yr, mNum));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(lbl,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: np >= 0 ? AppColors.successLight : AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(s.formatAmount(np.abs()),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: np >= 0 ? AppColors.success : AppColors.error)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Revenue', style: TextStyle(fontSize: 11, color: AppColors.navy500)),
                    Text(s.formatAmount(rev),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.info)),
                  ])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Gross Profit', style: TextStyle(fontSize: 11, color: AppColors.navy500)),
                    Text(s.formatAmount(gp),
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: gp >= 0 ? AppColors.success : AppColors.error)),
                  ])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Expenses', style: TextStyle(fontSize: 11, color: AppColors.navy500)),
                    Text(s.formatAmount(exp),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                  ])),
                ]),
              ]),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.navy500, letterSpacing: 0.5)),
  );

  Widget _subtotalRow(String label, double value, double pct, AppSettings s) {
    final isPos = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPos ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: isPos ? AppColors.success : AppColors.error))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.formatAmount(value.abs()),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: isPos ? AppColors.success : AppColors.error)),
          Text('${pct.toStringAsFixed(1)}% margin',
              style: TextStyle(fontSize: 10,
                  color: isPos ? AppColors.success : AppColors.error)),
        ]),
      ]),
    );
  }

  Widget _plRow(String label, double value, Color color, IconData icon, AppSettings s) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        Text(s.formatAmount(value),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ─── Stock Report Tab ─────────────────────────────────────────────────────────

class _StockTab extends StatelessWidget {
  final Map inventory;
  final AppSettings settings;
  const _StockTab({required this.inventory, required this.settings});

  @override
  Widget build(BuildContext context) {
    final s = inventory;
    final total     = s['total_products'] as int? ?? 0;
    final lowCount  = s['low_stock_count'] as int? ?? 0;
    final outCount  = s['out_of_stock_count'] as int? ?? 0;
    final stockVal  = (s['stock_value'] as num?)?.toDouble() ?? 0;
    final lowItems  = (s['low_stock_items'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Inventory Report',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            KpiCard(
              label: 'Total Products',
              value: '$total',
              icon: Icons.inventory_2_rounded,
              iconBg: AppColors.infoLight,
              iconColor: AppColors.info,
            ),
            KpiCard(
              label: 'Stock Value',
              value: settings.formatAmount(stockVal),
              icon: Icons.monetization_on_rounded,
              iconBg: AppColors.successLight,
              iconColor: AppColors.success,
            ),
            KpiCard(
              label: 'Low Stock',
              value: '$lowCount items',
              icon: Icons.warning_rounded,
              iconBg: AppColors.warningLight,
              iconColor: AppColors.warning,
            ),
            KpiCard(
              label: 'Out of Stock',
              value: '$outCount items',
              icon: Icons.remove_shopping_cart_rounded,
              iconBg: AppColors.errorLight,
              iconColor: AppColors.error,
            ),
          ],
        ),
        if (lowItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(children: [
            Container(
              width: 4, height: 18,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Low Stock Alert',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.warning)),
          ]),
          const SizedBox(height: 10),
          ...lowItems.map((p) {
            final name     = p['name'] as String? ?? '';
            final stock    = (p['stock_quantity'] as num?)?.toDouble() ?? 0;
            final minStock = (p['min_stock_level'] as num?)?.toDouble() ?? 0;
            final sku      = p['sku'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (sku.isNotEmpty)
                      Text(sku, style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${stock.toStringAsFixed(0)} left',
                        style: const TextStyle(fontWeight: FontWeight.w800,
                            color: AppColors.warning, fontSize: 14)),
                    Text('Min: ${minStock.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
                  ]),
                ]),
              ),
            );
          }),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Receivable Aging Tab ─────────────────────────────────────────────────────

class _AgingTab extends StatelessWidget {
  final Map aging;
  final AppSettings settings;
  const _AgingTab({required this.aging, required this.settings});

  @override
  Widget build(BuildContext context) {
    final total      = (aging['total_receivable'] as num?)?.toDouble() ?? 0;
    final current    = aging['current'] as Map? ?? {};
    final d31_60     = aging['days31_60'] as Map? ?? {};
    final d61_90     = aging['days61_90'] as Map? ?? {};
    final over90     = aging['over90'] as Map? ?? {};
    final topDebtors = (aging['top_debtors'] as List?) ?? [];

    final buckets = [
      (label: '0-30 days', data: current, color: AppColors.success),
      (label: '31-60 days', data: d31_60, color: AppColors.warning),
      (label: '61-90 days', data: d61_90, color: AppColors.orange),
      (label: '90+ days', data: over90, color: AppColors.error),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Receivable Aging Report',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Who owes you money & for how long',
            style: TextStyle(fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: 16),

        // Total card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.orange.withOpacity(0.2), AppColors.orange.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.orange, size: 32),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Outstanding',
                  style: TextStyle(fontSize: 13, color: AppColors.navy500)),
              Text(settings.formatAmount(total),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                      color: AppColors.orange)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Aging buckets
        ...buckets.map((b) {
          final count = b.data['count'] as int? ?? 0;
          final amt   = (b.data['total'] as num?)?.toDouble() ?? 0;
          final pct   = total > 0 ? amt / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: b.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Text('$count invoice${count != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.navy500)),
                  const SizedBox(width: 12),
                  Text(settings.formatAmount(amt),
                      style: TextStyle(fontWeight: FontWeight.w800, color: b.color, fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    backgroundColor: AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation(b.color),
                    minHeight: 6,
                  ),
                ),
              ]),
            ),
          );
        }),

        if (topDebtors.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Top Outstanding Customers',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...topDebtors.asMap().entries.map((e) {
            final i   = e.key;
            final d   = e.value as Map;
            final name = d['customer__name'] as String? ?? 'Walk-in';
            final due  = (d['total_due'] as num?)?.toDouble() ?? 0;
            final cnt  = d['invoice_count'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.orange.withOpacity(0.15),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: AppColors.orange,
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('$cnt invoice${cnt != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
                  ])),
                  Text(settings.formatAmount(due),
                      style: const TextStyle(fontWeight: FontWeight.w800,
                          color: AppColors.error, fontSize: 14)),
                ]),
              ),
            );
          }),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Sales Report Tab ─────────────────────────────────────────────────────────

class _SalesReportTab extends StatelessWidget {
  final List monthly;
  final AppSettings settings;
  const _SalesReportTab({required this.monthly, required this.settings});

  @override
  Widget build(BuildContext context) {
    final totalSales = monthly.fold<double>(
        0, (s, m) => s + ((m['revenue'] as num?)?.toDouble() ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.info, size: 28),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Sales (12 months)',
                  style: TextStyle(fontSize: 12, color: AppColors.navy500)),
              Text(settings.formatAmount(totalSales),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: AppColors.info)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Monthly Breakdown',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...monthly.map((m) {
          final rev = (m['revenue'] as num?)?.toDouble() ?? 0;
          final pct = totalSales > 0 ? rev / totalSales : 0.0;
          final mNum = (m['month'] as int? ?? 1);
          final yr   = (m['year'] as int? ?? 2024);
          final label = DateFormat('MMMM yyyy').format(DateTime(yr, mNum));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Text(settings.formatAmount(rev),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.info)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.info),
                    minHeight: 6,
                  ),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Day Book Tab ─────────────────────────────────────────────────────────────

class _DayBookTab extends StatelessWidget {
  final Map dayBook;
  final DateTime selectedDate;
  final AppSettings settings;
  final ValueChanged<DateTime> onDateChanged;

  const _DayBookTab({
    required this.dayBook,
    required this.selectedDate,
    required this.settings,
    required this.onDateChanged,
  });

  static const _typeColors = {
    'SALE': AppColors.info,
    'PURCHASE': Color(0xFF7C3AED),
    'EXPENSE': AppColors.error,
    'PAYMENT_IN': AppColors.success,
    'PAYMENT_OUT': AppColors.warning,
  };

  static const _typeIcons = {
    'SALE': Icons.receipt_long_rounded,
    'PURCHASE': Icons.local_shipping_rounded,
    'EXPENSE': Icons.money_off_rounded,
    'PAYMENT_IN': Icons.arrow_downward_rounded,
    'PAYMENT_OUT': Icons.arrow_upward_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final entries = (dayBook['entries'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final totalIn  = (dayBook['total_in']  as num?)?.toDouble() ?? 0;
    final totalOut = (dayBook['total_out'] as num?)?.toDouble() ?? 0;
    final netCash  = (dayBook['net_cash']  as num?)?.toDouble() ?? 0;
    final isPos    = netCash >= 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Text('Day Book',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(primary: AppColors.orange),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onDateChanged(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Text(DateFormat('dd MMM yyyy').format(selectedDate),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.orange,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _cashCard('Cash In',  totalIn,  AppColors.success, Icons.arrow_downward_rounded, s),
            const SizedBox(width: 10),
            _cashCard('Cash Out', totalOut, AppColors.error,   Icons.arrow_upward_rounded,   s),
            const SizedBox(width: 10),
            _cashCard('Net Cash', netCash,
                isPos ? AppColors.success : AppColors.error,
                isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded, s),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.book_outlined, size: 48, color: AppColors.navy500),
                    SizedBox(height: 12),
                    Text('No transactions on this date',
                        style: TextStyle(color: AppColors.navy500)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final e     = entries[i];
                    final type  = e['type']?.toString() ?? '';
                    final color = _typeColors[type] ?? AppColors.navy500;
                    final icon  = _typeIcons[type]  ?? Icons.circle_outlined;
                    final debit  = (e['debit']  as num?)?.toDouble() ?? 0;
                    final credit = (e['credit'] as num?)?.toDouble() ?? 0;
                    final isDark = s.isDark;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e['ref']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            if ((e['party']?.toString() ?? '').isNotEmpty)
                              Text(e['party'].toString(),
                                  style: const TextStyle(fontSize: 12, color: AppColors.navy500)),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(type.replaceAll('_', ' '),
                                    style: TextStyle(fontSize: 9, color: color,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 6),
                              Text(e['method']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 10, color: AppColors.navy500)),
                            ]),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (debit > 0)
                            Text('+${s.formatAmount(debit)}',
                                style: const TextStyle(color: AppColors.success,
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          if (credit > 0)
                            Text('-${s.formatAmount(credit)}',
                                style: const TextStyle(color: AppColors.error,
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _cashCard(String label, double value, Color color, IconData icon, AppSettings s) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(s.formatAmount(value.abs()),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
