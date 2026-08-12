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
  const TransactionsScreen({super.key, this.initialSubTab = 0});

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
            FeatureGate(feature: 'pos', child: SalesScreen()),
            FeatureGate(feature: 'purchases', child: PurchasesScreen()),
          ],
        ),
      ),
    );
  }
}
