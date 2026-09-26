import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/features/feature_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../router/dashboard_route.dart';
import '../../../../shared/widgets/announcement_banner.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/nepal_clock.dart';
import '../../../../shared/widgets/trial_banner.dart';
import '../../../auth/data/models/business_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../banking/presentation/providers/banking_provider.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../parties/presentation/screens/parties_screen.dart';
import '../../../parties/presentation/screens/party_payment_form.dart';
import '../../../purchases/presentation/providers/purchase_provider.dart';
import '../../../purchases/presentation/screens/purchase_return_screen.dart';
import '../../../reports/data/models/report_models.dart';
import '../../../reports/presentation/providers/report_provider.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../sales/presentation/screens/pos/quick_pos_screen.dart';
import '../../../sales/presentation/screens/sales_return_screen.dart';

/// Presentation only.
/// Data: ReportProvider / PurchaseProvider / BankingProvider / AuthProvider
/// (services + models stay in data layer; loads stay in providers).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    await Future.wait([
      context.read<ReportProvider>().loadDashboard(),
      context.read<ReportProvider>().loadWeeklyCashflow(),
      context.read<PurchaseProvider>().load(),
      context.read<BankingProvider>().load(),
    ]);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<ReportProvider>().loadDashboard(),
      context.read<ReportProvider>().loadWeeklyCashflow(),
      context.read<PurchaseProvider>().load(),
      context.read<BankingProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportProvider>();
    final d = rp.dashboard;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final padding = isTablet ? 24.0 : 16.0;
    final maxContent = isTablet ? 960.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: rp.isLoading && d == null
          ? const LoadingView()
          : d == null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load dashboard',
                  message: rp.error ?? 'Something went wrong',
                  action: PrimaryButton(
                    label: 'Retry',
                    expand: false,
                    onPressed: _load,
                  ),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(padding),
                  children: [
                    const AnnouncementBanner(),
                    const TrialBanner(),
                    const NepalClock(),
                    const SizedBox(height: 14),
                    _StatGrid(dashboard: d, isTablet: isTablet),
                    const SizedBox(height: 20),
                    const _ExploreAppRow(),
                    const SizedBox(height: 20),
                    const _CompleteProfileBanner(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Shortcuts'),
                    const SizedBox(height: 10),
                    const _ShortcutsGrid(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Cashflow (Last 7 Days)'),
                    const SizedBox(height: 10),
                    AppSectionCard(
                      children: [_CashflowChart(points: const [])],
                    ),
                    const SizedBox(height: 20),
                    if (d.topItems.isNotEmpty) ...[
                      const SectionHeader(title: 'Top Selling Items'),
                      const SizedBox(height: 10),
                      AppSectionCard(
                        children: [
                          for (var i = 0; i < d.topItems.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == d.topItems.length - 1 ? 0 : 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      d.topItems[i].productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${Formatters.amount(d.topItems[i].totalQty)} units',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    Formatters.currency(
                                      d.topItems[i].totalRevenue,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SectionHeader(title: 'Recent Sales'),
                    const SizedBox(height: 10),
                    if (d.recentSales.isEmpty)
                      AppSectionCard(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No sales yet',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    else
                      AppSectionCard(
                        children: [
                          for (var i = 0; i < d.recentSales.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == d.recentSales.length - 1 ? 0 : 14,
                              ),
                              child: InkWell(
                                onTap: () => context.push(
                                  '/invoice/${d.recentSales[i].id}',
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.recentSales[i].invoiceNumber,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            d
                                                    .recentSales[i]
                                                    .customerName
                                                    .isNotEmpty
                                                ? d.recentSales[i].customerName
                                                : 'Cash Sales',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      Formatters.currency(
                                        d.recentSales[i].total,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    StatusBadge(label: d.recentSales[i].status),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final DashboardSummary dashboard;
  final bool isTablet;

  const _StatGrid({required this.dashboard, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final purchaseMonth = context.watch<PurchaseProvider>().thisMonthTotal;
    final totalBalance = context.watch<BankingProvider>().totalBalance;
    // A staff member only sees the figures for modules the owner gave them
    // (the server zeroes the rest anyway) - no misleading "Rs 0" cards.
    final business = context.watch<AuthProvider>().currentBusiness;
    bool allowed(String module) => business?.can(module) ?? true;

    return ResponsiveGrid(
      columns: isTablet ? 3 : 2,
      spacing: 12,
      childAspectRatio: isTablet ? 1.9 : 1.35,
      children: [
        if (allowed('parties'))
        _StatCard(
          value: Formatters.currency(d.totalReceivable),
          label: 'To Receive',
          icon: Icons.arrow_downward,
          background: AppColors.successBg,
          valueColor: AppColors.success,
          onTap: () => context.push('/reports'),
        ),
        if (allowed('parties'))
        _StatCard(
          value: Formatters.currency(d.totalPayable),
          label: 'To Give',
          icon: Icons.arrow_upward,
          background: AppColors.errorBg,
          valueColor: AppColors.error,
          onTap: () => context.push('/reports'),
        ),
        if (allowed('sales'))
        _StatCard(
          value: Formatters.currency(d.salesMonth),
          label: 'Sales (This Month)',
          // Sales/Purchases aren't standalone routes — they're sub-tabs of
          // the "Transactions" shell tab (see TransactionsScreen). go()
          // (not push()) replaces the stack, same as tapping the bottom nav.
          onTap: () => context.go(dashboardLocation(tab: 1, subtab: 0)),
        ),
        if (allowed('purchases'))
        _StatCard(
          value: Formatters.currency(purchaseMonth),
          label: 'Purchase (This Month)',
          onTap: () => context.go(dashboardLocation(tab: 1, subtab: 1)),
        ),
        if (allowed('expenses'))
        _StatCard(
          value: Formatters.currency(d.expensesMonth),
          label: 'Expense (This Month)',
          onTap: () => context.push('/expenses'),
        ),
        if (allowed('banking'))
        _StatCard(
          value: Formatters.currency(totalBalance),
          label: 'Total Balance',
          sublabel: 'Cash & Bank',
          onTap: () => context.push('/banking'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? sublabel;
  final IconData? icon;
  final Color? background;
  final Color? valueColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.label,
    this.sublabel,
    this.icon,
    this.background,
    this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background ?? AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: background == null
                ? [
                    BoxShadow(
                      color: AppColors.navy900.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          // FittedBox scales the whole card down to fit its grid cell instead
          // of overflowing — robust against narrow phones, long currency
          // values, and larger accessibility font scales alike.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: valueColor ?? AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: (valueColor ?? AppColors.navy300).withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 4),
                      Icon(icon, size: 13, color: valueColor),
                    ],
                  ],
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.navy300,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreAppRow extends StatelessWidget {
  const _ExploreAppRow();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Explore App',
      children: [
        Row(
          children: [
            Expanded(
              child: _ExploreTile(
                icon: Icons.flash_on_outlined,
                label: 'Quick Entry',
                onTap: () => _openShortcutsSheet(context),
              ),
            ),
            Expanded(
              child: _ExploreTile(
                icon: Icons.point_of_sale_outlined,
                label: 'Quick POS',
                onTap: () => context.push('/pos'),
              ),
            ),
            Expanded(
              child: _ExploreTile(
                icon: Icons.bar_chart_outlined,
                label: 'View Reports',
                onTap: () => context.push('/reports'),
              ),
            ),
            Expanded(
              child: _ExploreTile(
                icon: Icons.notifications_active_outlined,
                label: 'Credit Reminder',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReportsScreen(initialTabIndex: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExploreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExploreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.orangeDark, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteProfileBanner extends StatelessWidget {
  const _CompleteProfileBanner();

  int _completionPercent(Business? b) {
    if (b == null) return 0;
    final fields = <bool>[
      b.name.isNotEmpty,
      b.address.isNotEmpty,
      b.phone.isNotEmpty,
      b.email.isNotEmpty,
      b.panNumber.isNotEmpty,
      b.vatNumber.isNotEmpty,
      b.businessType.isNotEmpty,
      b.logo != null,
    ];
    final filled = fields.where((f) => f).length;
    return ((filled / fields.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<AuthProvider>().currentBusiness;
    final pct = _completionPercent(business);
    if (pct >= 100) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/settings'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.navyGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 4,
                      backgroundColor: Colors.white24,
                      color: AppColors.orange,
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add your business details to unlock everything.',
                      style: TextStyle(
                        color: AppColors.navy200,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

void _openShortcutsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(title: 'Quick Entry'),
          SizedBox(height: 16),
          _ShortcutsGrid(),
        ],
      ),
    ),
  );
}

class _ShortcutsGrid extends StatelessWidget {
  const _ShortcutsGrid();

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureProvider>();
    final shortcuts = <_ShortcutItem>[
      _ShortcutItem(
        Icons.person_add_alt_outlined,
        'Add Party',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PartiesScreen(openAddOnStart: true),
          ),
        ),
      ),
      _ShortcutItem(
        Icons.receipt_long_outlined,
        'Sales Invoice',
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QuickPosScreen())),
      ),
      _ShortcutItem(
        Icons.call_received,
        'Receive',
        () => showPartyPaymentForm(context, paymentType: 'IN'),
      ),
      _ShortcutItem(
        Icons.call_made,
        'Give',
        () => showPartyPaymentForm(context, paymentType: 'OUT'),
      ),
      _ShortcutItem(
        Icons.shopping_bag_outlined,
        'Purchase',
        () => context.go(dashboardLocation(tab: 1, subtab: 1)),
      ),
      // Goods coming back: from a customer (stock restored) or going back to a
      // supplier (stock reduced). Each opens its form directly; hidden if the
      // owner has switched that module off.
      if (features.isEnabled('pos'))
        _ShortcutItem(
          Icons.assignment_return_outlined,
          'Sales Return',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SalesReturnFormScreen()),
          ),
        ),
      if (features.isEnabled('purchases'))
        _ShortcutItem(
          Icons.undo_outlined,
          'Purchase Return',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PurchaseReturnFormScreen()),
          ),
        ),
      _ShortcutItem(
        Icons.inventory_2_outlined,
        'Add Item',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const InventoryScreen(openAddOnStart: true),
          ),
        ),
      ),
      _ShortcutItem(
        Icons.wallet_outlined,
        'Expense',
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ExpensesScreen(openAddOnStart: true),
          ),
        ),
      ),
    ];

    return ResponsiveGrid(
      columns: 4,
      spacing: 14,
      childAspectRatio: 0.72,
      children: shortcuts
          .map(
            (s) => _ExploreTile(icon: s.icon, label: s.label, onTap: s.onTap),
          )
          .toList(),
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ShortcutItem(this.icon, this.label, this.onTap);
}

class _CashflowChart extends StatelessWidget {
  final List<DayBook> points;
  const _CashflowChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    var maxY = 0.0;
    for (final p in points) {
      if (p.totalIn > maxY) maxY = p.totalIn;
      if (p.totalOut > maxY) maxY = p.totalOut;
    }
    maxY = maxY <= 0 ? 100 : maxY * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.divider,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      Formatters.amount(value),
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final date = points[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          date != null ? Formatters.dateShort(date) : '',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    points.length,
                    (i) => FlSpot(i.toDouble(), points[i].totalIn),
                  ),
                  isCurved: true,
                  color: AppColors.success,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.success.withValues(alpha: 0.08),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                    points.length,
                    (i) => FlSpot(i.toDouble(), points[i].totalOut),
                  ),
                  isCurved: true,
                  color: AppColors.error,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.error.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _legendDot(
              AppColors.success,
              'Total Money In',
              points.fold(0.0, (s, p) => s + p.totalIn),
            ),
            const SizedBox(width: 20),
            _legendDot(
              AppColors.error,
              'Total Money Out',
              points.fold(0.0, (s, p) => s + p.totalOut),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, double total) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.currency(total),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
