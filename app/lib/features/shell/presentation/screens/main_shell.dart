import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode.dart';
import '../../../../shared/widgets/feature_gate.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../parties/presentation/screens/parties_screen.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import 'more_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  /// Sub-tab within the Transactions tab (0 = Sales, 1 = Purchases) — only
  /// relevant when [initialIndex] is 1.
  final int initialSubTab;
  const MainShell({super.key, this.initialIndex = 0, this.initialSubTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Keying by the calendar + theme + language preference forces the tabs
    // to fully remount (instead of staying cached in the IndexedStack)
    // whenever any of them changes, so every date/color/label on screen —
    // which read the mutable Formatters/AppColors/AppTranslations globals
    // directly rather than Theme.of(context) — re-renders with the newly
    // selected value instead of staying frozen at whatever it was on last build.
    final useNepaliCalendar = context.select<SettingsProvider, bool>((s) => s.settings.showNepaliCalendar);
    final themeMode = context.select<SettingsProvider, AppThemeMode>((s) => s.settings.themeMode);
    final hideAmounts = context.select<SettingsProvider, bool>((s) => s.settings.hideAmounts);
    final language = context.select<SettingsProvider, String>((s) => s.settings.language);
    final screens = [
      const DashboardScreen(),
      TransactionsScreen(initialSubTab: widget.initialSubTab),
      const FeatureGate(feature: 'parties', child: PartiesScreen()),
      const FeatureGate(feature: 'inventory', child: InventoryScreen()),
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
              actions: [
                IconButton(
                  tooltip: hideAmounts ? 'Show amounts' : 'Hide amounts',
                  icon: Icon(hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => context.read<SettingsProvider>().setHideAmounts(!hideAmounts),
                ),
              ],
            )
          : null,
      body: ResponsiveBody(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                key: ValueKey('$useNepaliCalendar-$themeMode-$hideAmounts-$language'),
                index: _index,
                children: screens,
              ),
            ),
          ],
        ),
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
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: t('home')),
              BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), activeIcon: const Icon(Icons.receipt_long), label: t('transactions')),
              BottomNavigationBarItem(icon: const Icon(Icons.people_outline), activeIcon: const Icon(Icons.people), label: t('parties')),
              BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_outlined), activeIcon: const Icon(Icons.inventory_2), label: t('inventory')),
              BottomNavigationBarItem(icon: const Icon(Icons.grid_view_outlined), activeIcon: const Icon(Icons.grid_view), label: t('more')),
            ],
          ),
        ),
      ),
    );
  }
}
