import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    try {
      final r1 = await api.get('/reports/monthly/');
      final r2 = await api.get('/reports/dashboard-summary/');
      _monthly = (r1.data as List?) ?? [];
      _summary = (r2.data as Map?) ?? {};
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
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sales'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                    monthly: _monthly,
                    summary: _summary,
                    settings: settings),
                _SalesReportTab(monthly: _monthly, settings: settings),
                _ExpenseReportTab(monthly: _monthly, settings: settings),
              ],
            ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final List monthly;
  final Map summary;
  final AppSettings settings;
  const _OverviewTab(
      {required this.monthly,
      required this.summary,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final totalRevenue = monthly.fold<double>(
        0, (s, m) => s + (double.tryParse(m['revenue']?.toString() ?? '0') ?? 0));
    final totalExpenses = monthly.fold<double>(
        0,
        (s, m) =>
            s + (double.tryParse(m['expenses']?.toString() ?? '0') ?? 0));
    final netProfit = totalRevenue - totalExpenses;

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI row
          Row(children: [
            Expanded(
              child: KpiCard(
                label: settings.t('revenue'),
                value: settings.formatAmount(totalRevenue),
                icon: Icons.trending_up_rounded,
                iconBg: AppColors.info.withOpacity(0.15),
                iconColor: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: settings.t('total_expenses'),
                value: settings.formatAmount(totalExpenses),
                icon: Icons.trending_down_rounded,
                iconBg: AppColors.errorLight,
                iconColor: AppColors.error,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: netProfit >= 0
                      ? AppColors.successLight
                      : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  netProfit >= 0
                      ? Icons.emoji_events_rounded
                      : Icons.warning_rounded,
                  color: netProfit >= 0 ? AppColors.success : AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    netProfit >= 0
                        ? settings.t('net_profit')
                        : settings.t('loss'),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.navy500),
                  ),
                  Text(
                    settings.formatAmount(netProfit.abs()),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: netProfit >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // Bar chart
          if (monthly.isNotEmpty) ...[
            const Text('12-Month Overview',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: monthly.fold<double>(
                          0,
                          (m, d) => m >
                                  (double.tryParse(
                                          d['revenue']?.toString() ?? '0') ??
                                      0)
                              ? m
                              : (double.tryParse(
                                      d['revenue']?.toString() ?? '0') ??
                                  0),
                        ) *
                        1.2,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= monthly.length) {
                              return const SizedBox();
                            }
                            final m =
                                monthly[idx]['month']?.toString() ?? '';
                            return Text(m.length >= 3 ? m.substring(0, 3) : m,
                                style: const TextStyle(fontSize: 9));
                          },
                          reservedSize: 20,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.lightBorder.withOpacity(0.5),
                          strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: monthly.asMap().entries.map((e) {
                      final i = e.key;
                      final d = e.value;
                      final rev = double.tryParse(
                              d['revenue']?.toString() ?? '0') ??
                          0;
                      final exp = double.tryParse(
                              d['expenses']?.toString() ?? '0') ??
                          0;
                      final prof = double.tryParse(
                              d['profit']?.toString() ?? '0') ??
                          0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                              toY: rev,
                              color: AppColors.info,
                              width: 6,
                              borderRadius: BorderRadius.circular(3)),
                          BarChartRodData(
                              toY: exp,
                              color: AppColors.error,
                              width: 6,
                              borderRadius: BorderRadius.circular(3)),
                          BarChartRodData(
                              toY: prof.abs(),
                              color: AppColors.orange,
                              width: 6,
                              borderRadius: BorderRadius.circular(3)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final item in [
                (AppColors.info, settings.t('revenue')),
                (AppColors.error, settings.t('total_expenses')),
                (AppColors.orange, settings.t('profit')),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: item.$1,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Text(item.$2,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.navy500)),
                  ]),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          // Additional stats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              KpiCard(
                label: settings.t('receivable'),
                value: settings.formatAmount(double.tryParse(
                        summary['total_receivable']?.toString() ?? '0') ??
                    0),
                icon: Icons.arrow_downward_rounded,
                iconBg: AppColors.successLight,
                iconColor: AppColors.success,
              ),
              KpiCard(
                label: settings.t('payable'),
                value: settings.formatAmount(double.tryParse(
                        summary['total_payable']?.toString() ?? '0') ??
                    0),
                icon: Icons.arrow_upward_rounded,
                iconBg: AppColors.errorLight,
                iconColor: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesReportTab extends StatelessWidget {
  final List monthly;
  final AppSettings settings;
  const _SalesReportTab(
      {required this.monthly, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Monthly Sales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...monthly.map((m) {
          final rev = double.tryParse(m['revenue']?.toString() ?? '0') ?? 0;
          final totalRev = monthly.fold<double>(
              0,
              (s, x) =>
                  s + (double.tryParse(x['revenue']?.toString() ?? '0') ?? 0));
          final pct = totalRev > 0 ? (rev / totalRev * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(m['month'] ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13))),
                    Text(settings.formatAmount(rev),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.info)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).toDouble(),
                      backgroundColor: AppColors.lightBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.info),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ExpenseReportTab extends StatelessWidget {
  final List monthly;
  final AppSettings settings;
  const _ExpenseReportTab(
      {required this.monthly, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Monthly Expenses',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...monthly.map((m) {
          final exp = double.tryParse(m['expenses']?.toString() ?? '0') ?? 0;
          final totalExp = monthly.fold<double>(
              0,
              (s, x) =>
                  s +
                  (double.tryParse(x['expenses']?.toString() ?? '0') ?? 0));
          final pct = totalExp > 0 ? (exp / totalExp * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(m['month'] ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13))),
                    Text(settings.formatAmount(exp),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.error)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).toDouble(),
                      backgroundColor: AppColors.lightBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.error),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
