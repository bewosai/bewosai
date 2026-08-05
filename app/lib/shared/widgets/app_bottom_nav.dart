import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Same 5 tabs as [MainShell]'s bar, reused on every pushed screen so the
/// bottom nav stays visible and functional app-wide. Tapping a tab jumps
/// straight to MainShell on that tab (`/dashboard?tab=N`), replacing the
/// current stack — same as tapping it from within MainShell itself, just
/// reached from a route outside the shell.
class AppBottomNav extends StatelessWidget {
  /// Which of the 5 tabs this screen is conceptually "under" (highlighted).
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: AppColors.navy900.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            HapticFeedback.selectionClick();
            context.go('/dashboard?tab=$i');
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
    );
  }
}
