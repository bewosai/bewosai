import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../pos/quick_pos_screen.dart';
import '../search/global_search_screen.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/dashboard', icon: Icons.grid_view_rounded, label: 'dashboard'),
    (path: '/sales', icon: Icons.receipt_long_rounded, label: 'sales'),
    (path: '/inventory', icon: Icons.inventory_2_rounded, label: 'inventory'),
    (path: '/parties', icon: Icons.people_rounded, label: 'parties'),
    (path: '/more', icon: Icons.apps_rounded, label: 'more'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      // Quick POS floating action button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuickPosScreen()),
        ),
        child: const Icon(Icons.point_of_sale_rounded, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (_tabs[i].path == '/more') {
            _showMoreMenu(context, settings);
          } else {
            context.go(_tabs[i].path);
          }
        },
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: settings.t(t.label),
                ))
            .toList(),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(
                child: Text(
                  'More',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              // Global search button
              IconButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const GlobalSearchScreen()),
                  );
                },
                icon: const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.orange.withOpacity(0.1),
                  foregroundColor: AppColors.orange,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                for (final item in [
                  (
                    '/expenses',
                    Icons.account_balance_wallet_rounded,
                    'Expenses',
                    AppColors.error,
                  ),
                  (
                    '/purchases',
                    Icons.local_shipping_rounded,
                    'Purchases',
                    const Color(0xFF7C3AED),
                  ),
                  (
                    '/payments',
                    Icons.payment_rounded,
                    'Payments',
                    AppColors.success,
                  ),
                  (
                    '/banking',
                    Icons.account_balance_rounded,
                    'Banking',
                    AppColors.info,
                  ),
                  (
                    '/reports',
                    Icons.bar_chart_rounded,
                    'Reports',
                    AppColors.orange,
                  ),
                  (
                    '/staff',
                    Icons.badge_rounded,
                    'Staff',
                    AppColors.navy600,
                  ),
                  (
                    '/recycle-bin',
                    Icons.delete_sweep_rounded,
                    'Recycle Bin',
                    AppColors.navy500,
                  ),
                  (
                    '/settings',
                    Icons.settings_rounded,
                    'Settings',
                    AppColors.navy500,
                  ),
                ])
                  _MoreItem(
                    icon: item.$2,
                    label: item.$3,
                    color: item.$4,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go(item.$1);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
