import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/dashboard', icon: Icons.grid_view_rounded, label: 'dashboard'),
    (path: '/sales', icon: Icons.receipt_long_rounded, label: 'sales'),
    (
      path: '/purchases',
      icon: Icons.local_shipping_rounded,
      label: 'purchases'
    ),
    (
      path: '/expenses',
      icon: Icons.account_balance_wallet_rounded,
      label: 'expenses'
    ),
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
        padding: const EdgeInsets.all(20),
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
            const Text(
              'More',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                for (final item in [
                  (
                    '/inventory',
                    Icons.inventory_2_rounded,
                    'Inventory'
                  ),
                  ('/parties', Icons.people_rounded, 'Parties'),
                  ('/payments', Icons.payment_rounded, 'Payments'),
                  ('/reports', Icons.bar_chart_rounded, 'Reports'),
                  ('/staff', Icons.badge_rounded, 'Staff'),
                  ('/settings', Icons.settings_rounded, 'Settings'),
                ])
                  _MoreItem(
                    icon: item.$2,
                    label: item.$3,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go(item.$1);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreItem(
      {required this.icon, required this.label, required this.onTap});

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
              color: AppColors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.orange, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
