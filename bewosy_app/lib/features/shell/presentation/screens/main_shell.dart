import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../parties/presentation/screens/parties_screen.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import 'more_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Keying by the calendar preference forces the tabs to fully remount
    // (instead of staying cached in the IndexedStack) whenever it changes,
    // so every date on screen re-renders in the newly selected calendar.
    final useNepaliCalendar = context.select<SettingsProvider, bool>((s) => s.settings.showNepaliCalendar);
    final screens = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const PartiesScreen(),
      const InventoryScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      appBar: _index == 0
          ? AppBar(
              titleSpacing: 12,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.orangeLight,
                    child: Text(
                      auth.currentBusiness?.name.isNotEmpty == true ? auth.currentBusiness!.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.read<AuthProvider>().switchBusiness(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              auth.currentBusiness?.name ?? '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: IndexedStack(
        key: ValueKey(useNepaliCalendar),
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: AppColors.navy900.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Transactions'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Parties'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Inventory'),
              BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view), label: 'More'),
            ],
          ),
        ),
      ),
    );
  }
}
