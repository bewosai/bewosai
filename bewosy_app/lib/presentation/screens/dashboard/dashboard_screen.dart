import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dashData;
  List<Map<String, dynamic>> _monthlyData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final biz = context.read<BusinessProvider>();
    try {
      final results = await Future.wait([
        biz.getDashboardSummary(),
        biz.getMonthlyReport(),
      ]);
      setState(() {
        _dashData = results[0] as Map<String, dynamic>;
        _monthlyData = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.orange,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              snap: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 20, bottom: 14),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      settings.t('dashboard'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      auth.currentBusiness?.name ?? 'My Business',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.navy500),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(settings.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded),
                  onPressed: () => settings.setTheme(settings.isDark
                      ? ThemeMode.light
                      : ThemeMode.dark),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _loading
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.orange),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        _buildKpiGrid(settings),
                        const SizedBox(height: 16),
                        _buildAlerts(context, settings),
                        const SizedBox(height: 16),
                        _buildProfitLossChart(settings),
                        const SizedBox(height: 16),
                        _buildQuickActions(context, settings),
                        const SizedBox(height: 16),
                        _buildRecentSales(settings),
                        const SizedBox(height: 80),
                      ]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_fab',
        onPressed: () => context.go('/sales'),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(settings.t('new_invoice')),
      ),
    );
  }

  Widget _buildKpiGrid(AppSettings settings) {
    final d = _dashData;
    final kpis = [
      (
        label: settings.t('today_sales'),
        value: settings.formatAmount(
            double.tryParse(d?['sales_today']?.toString() ?? '0') ?? 0),
        icon: Icons.trending_up_rounded,
        bg: AppColors.infoLight,
        color: AppColors.info,
      ),
      (
        label: settings.t('month_sales'),
        value: settings.formatAmount(
            double.tryParse(d?['sales_month']?.toString() ?? '0') ?? 0),
        icon: Icons.bar_chart_rounded,
        bg: AppColors.successLight,
        color: AppColors.success,
      ),
      (
        label: settings.t('receivable'),
        value: settings.formatAmount(
            double.tryParse(
                    d?['total_receivable']?.toString() ?? '0') ??
                0),
        icon: Icons.account_balance_wallet_outlined,
        bg: AppColors.warningLight,
        color: AppColors.warning,
      ),
      (
        label: settings.t('net_profit'),
        value: settings.formatAmount(
            double.tryParse(d?['profit_month']?.toString() ?? '0') ??
                0),
        icon: Icons.monetization_on_outlined,
        bg: const Color(0xFFE9D5FF),
        color: const Color(0xFF7C3AED),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: kpis
          .map((k) => KpiCard(
                label: k.label,
                value: k.value,
                icon: k.icon,
                iconBg: k.bg,
                iconColor: k.color,
              ))
          .toList(),
    );
  }

  Widget _buildProfitLossChart(AppSettings settings) {
    if (_monthlyData.isEmpty) return const SizedBox();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final maxY = _monthlyData
            .map((m) => (m['revenue'] as num?)?.toDouble() ?? 0)
            .fold(0.0, (a, b) => a > b ? a : b) *
        1.2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.t('profit_loss'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Last 12 months',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.navy500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '12M',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.orange,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(enabled: true),
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
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 ||
                            idx >= _monthlyData.length) {
                          return const SizedBox();
                        }
                        final m =
                            (_monthlyData[idx]['month'] as int? ??
                                    1) -
                                1;
                        return Text(
                          months[m].substring(0, 3),
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.navy500),
                        );
                      },
                      reservedSize: 20,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.navy50,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_monthlyData.length, (i) {
                  final m = _monthlyData[i];
                  final rev =
                      (m['revenue'] as num?)?.toDouble() ?? 0;
                  final exp =
                      (m['expenses'] as num?)?.toDouble() ?? 0;
                  final prof =
                      (m['profit'] as num?)?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rev,
                        color: AppColors.info.withOpacity(0.8),
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: exp,
                        color: AppColors.error.withOpacity(0.8),
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: prof > 0 ? prof : 0,
                        color: AppColors.orange,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final item in [
                (AppColors.info, 'Revenue'),
                (AppColors.error, 'Expenses'),
                (AppColors.orange, 'Profit'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.$1,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.$2,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.navy500),
                    ),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppSettings settings) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (final item in [
                (
                  '/sales',
                  Icons.receipt_long_rounded,
                  'New Sale',
                  AppColors.info
                ),
                (
                  '/purchases',
                  Icons.add_shopping_cart_rounded,
                  'Purchase',
                  const Color(0xFF7C3AED)
                ),
                (
                  '/expenses',
                  Icons.money_off_rounded,
                  'Expense',
                  AppColors.error
                ),
                (
                  '/parties',
                  Icons.person_add_rounded,
                  'Add Party',
                  AppColors.success
                ),
              ])
                GestureDetector(
                  onTap: () => context.go(item.$1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.$4.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: item.$4.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(item.$2,
                            color: item.$4, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$3,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts(BuildContext context, AppSettings settings) {
    final lowStock   = (_dashData?['low_stock_count'] as int?) ?? 0;
    final receivable = (double.tryParse(_dashData?['total_receivable']?.toString() ?? '0') ?? 0);
    final payable    = (double.tryParse(_dashData?['total_payable']?.toString() ?? '0') ?? 0);

    if (lowStock == 0 && receivable == 0 && payable == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alerts & Reminders',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (lowStock > 0)
          _alertTile(
            context,
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            title: '$lowStock product${lowStock != 1 ? 's' : ''} low on stock',
            subtitle: 'Tap to view and restock',
            route: '/inventory',
          ),
        if (receivable > 0)
          _alertTile(
            context,
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.info,
            title: '${settings.formatAmount(receivable)} receivable',
            subtitle: 'Customers owe you money',
            route: '/payments',
          ),
        if (payable > 0)
          _alertTile(
            context,
            icon: Icons.payment_rounded,
            color: AppColors.error,
            title: '${settings.formatAmount(payable)} payable',
            subtitle: 'You owe suppliers',
            route: '/payments',
          ),
      ],
    );
  }

  Widget _alertTile(BuildContext context,
      {required IconData icon, required Color color, required String title,
       required String subtitle, required String route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
            ])),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentSales(AppSettings settings) {
    final sales =
        (_dashData?['recent_sales'] as List?) ?? [];
    if (sales.isEmpty) return const SizedBox();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(children: [
            Text(
              settings.t('recent_sales'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/sales'),
              child: const Text(
                'View all â†’',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        for (final sale in sales.take(5))
          ListTile(
            leading: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_rounded,
                  color: AppColors.info, size: 18),
            ),
            title: Text(
              sale['invoice_number'] ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${sale['customer_name'] ?? 'Walk-in'} Â· ${sale['sale_date'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  settings.formatAmount(
                      double.tryParse(
                              sale['total']?.toString() ?? '0') ??
                          0),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                StatusBadge(status: sale['status'] ?? ''),
              ],
            ),
          ),
      ]),
    );
  }
}


