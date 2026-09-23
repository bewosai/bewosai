import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../purchases/presentation/screens/purchases_screen.dart';
import '../../../sales/presentation/screens/sales_screen.dart';

/// The "Transactions" tab — sales and purchases used to be separate bottom-nav
/// tabs; they're combined here under sub-tabs so the main nav has room for
/// "More" instead.
class TransactionsScreen extends StatefulWidget {
  /// 0 = Sales, 1 = Purchases — which sub-tab to land on (e.g. the
  /// Dashboard's "Purchase (This Month)" card jumps here on index 1).
  final int initialSubTab;
  /// See MainShell.navToken: a new value re-applies [initialSubTab] even when it
  /// is the same as last time (the user may have switched sub-tab by hand since).
  final String requestToken;
  const TransactionsScreen({super.key, this.initialSubTab = 0, this.requestToken = ''});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialSubTab.clamp(0, 1),
  );

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This screen lives inside MainShell's IndexedStack and stays mounted
    // once built, so re-landing here (e.g. the Home screen's "Purchase"
    // shortcut going to subtab 1 a second time) only updates this prop —
    // it never recreates _tabController's initialIndex above.
    if (widget.initialSubTab != oldWidget.initialSubTab || widget.requestToken != oldWidget.requestToken) {
      _tabController.index = widget.initialSubTab.clamp(0, 1);
    }
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
        title: const Text('Transactions'),
        actions: const [HomeLogoButton()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.orange,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Purchases'),
          ],
        ),
      ),
      body: ResponsiveBody(
        child: TabBarView(
          controller: _tabController,
          children: const [
            FeatureGate(feature: 'pos', module: 'sales', child: SalesScreen()),
            FeatureGate(feature: 'purchases', module: 'purchases', child: PurchasesScreen()),
          ],
        ),
      ),
    );
  }
}
