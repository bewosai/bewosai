import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/presentation/screens/reports_hub_screen.dart';
import 'settings_account_screen.dart';
import 'settings_advanced_screen.dart';
import 'settings_business_screen.dart';
import 'settings_preferences_screen.dart';
import 'settings_tax_screen.dart';

/// Settings home: a grouped menu of focused sub-pages rather than one long
/// scroll — each row only exists because the feature behind it is real.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime with a new code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log Out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _GroupLabel('GENERAL'),
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'View Report',
                subtitle: 'Stock, sales, cash, bank statements & more',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsHubScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.storefront_outlined,
                label: 'Business Profile',
                subtitle: 'Name, type, phone, address',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsBusinessScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.person_outline,
                label: 'Account',
                subtitle: 'Your name and phone number',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsAccountScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.tune_outlined,
                label: 'App Preferences',
                subtitle: 'Theme, Bikram Sambat calendar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPreferencesScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Tax & Compliance',
                subtitle: 'PAN, VAT, currency, fiscal year',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsTaxScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            const _GroupLabel('DANGER ZONE'),
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.warning_amber_outlined,
                label: 'Advanced',
                subtitle: 'Close fiscal year, archive, delete',
                iconColor: AppColors.error,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsAdvancedScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: auth.isLoading ? null : _logout,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Bewosai · Business Suite',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Version ${_appVersion ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;
  _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(item: items[i]),
            if (i != items.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(item.icon, size: 22, color: item.iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: item.iconColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.navy300),
          ],
        ),
      ),
    );
  }
}
