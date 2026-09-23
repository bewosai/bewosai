import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/features/feature_provider.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/presentation/screens/inventory_import_screen.dart';
import '../../../parties/presentation/screens/party_import_screen.dart';
import '../../../purchases/presentation/screens/purchase_return_screen.dart';
import '../../../sales/presentation/screens/sales_return_screen.dart';
import 'contact_screen.dart';

class _MoreTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? feature;
  // The staff permission needed to see this tile (module + action).
  final String? module;
  final String action;
  const _MoreTile(this.icon, this.label, this.onTap, {this.feature, this.module, this.action = 'view'});
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final features = context.watch<FeatureProvider>();
    final user = auth.user;
    final business = auth.currentBusiness;

    final businessTiles = [
      _MoreTile(Icons.point_of_sale_outlined, 'Quick POS', () => context.push('/pos'), feature: 'pos', module: 'sales', action: 'create'),
      _MoreTile(
        Icons.assignment_return_outlined,
        'Sales Return',
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesReturnScreen())),
        feature: 'pos',
        module: 'sales',
      ),
      _MoreTile(
        Icons.undo_outlined,
        'Purchase Return',
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurchaseReturnScreen())),
        feature: 'purchases',
        module: 'purchases',
      ),
      _MoreTile(Icons.receipt_outlined, t('expenses'), () => context.push('/expenses'), feature: 'expenses', module: 'expenses'),
      _MoreTile(Icons.account_balance_outlined, t('banking'), () => context.push('/banking'), feature: 'banking', module: 'banking'),
      _MoreTile(Icons.bar_chart_outlined, t('reports'), () => context.push('/reports'), feature: 'reports', module: 'reports'),
      _MoreTile(Icons.badge_outlined, t('staff'), () => context.push('/staff'), feature: 'staff_management', module: 'staff'),
    ]
        .where((tile) => tile.feature == null || features.isEnabled(tile.feature!))
        .where((tile) => tile.module == null || (business?.can(tile.module!, tile.action) ?? true))
        .toList();

    final importTiles = [
      _MoreTile(
        Icons.inventory_2_outlined,
        'Import Products',
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryImportScreen())),
        feature: 'excel_import',
        module: 'inventory',
        action: 'create',
      ),
      _MoreTile(
        Icons.people_outline,
        'Import Parties',
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartyImportScreen())),
        feature: 'excel_import',
        module: 'parties',
        action: 'create',
      ),
    ]
        .where((tile) => tile.feature == null || features.isEnabled(tile.feature!))
        .where((tile) => tile.module == null || (business?.can(tile.module!, tile.action) ?? true))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(t('more')), actions: const [HomeLogoButton()]),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              onTap: () => context.push('/settings'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.orangeLight,
                    child: Text(
                      user?.initial ?? '?',
                      style: const TextStyle(
                        color: AppColors.orangeDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name.isNotEmpty == true
                              ? user!.name
                              : (user?.email ?? ''),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          business?.name ?? '',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.navy300),
                ],
              ),
            ),
            if (businessTiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Business'),
              const SizedBox(height: 10),
              AppSectionCard(
                children: [
                  for (var i = 0; i < businessTiles.length; i++) ...[
                    if (i > 0) _divider(),
                    _tile(context, businessTiles[i].icon, businessTiles[i].label, businessTiles[i].onTap),
                  ],
                ],
              ),
            ],
            if (importTiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Bulk Import'),
              const SizedBox(height: 10),
              AppSectionCard(
                children: [
                  for (var i = 0; i < importTiles.length; i++) ...[
                    if (i > 0) _divider(),
                    _tile(context, importTiles[i].icon, importTiles[i].label, importTiles[i].onTap),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            const SectionHeader(title: 'Account'),
            const SizedBox(height: 10),
            AppSectionCard(
              children: [
                _tile(
                  context,
                  Icons.business_outlined,
                  'Switch Business',
                  () => auth.switchBusiness(),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.settings_outlined,
                  t('settings'),
                  () => context.push('/settings'),
                ),
                // Only for someone who may delete something (the bin holds what was deleted).
                if (business?.canDeleteAnything ?? true) ...[
                  _divider(),
                  _tile(
                    context,
                    Icons.delete_outline,
                    t('recycleBin'),
                    () => context.push('/recycle-bin'),
                  ),
                ],
                _divider(),
                _tile(
                  context,
                  Icons.contact_support_outlined,
                  'Contact Us',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppSectionCard(
              children: [
                _tile(
                  context,
                  Icons.logout,
                  t('logout'),
                  () => auth.logout(),
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 20, color: AppColors.divider);

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: color ?? AppColors.navy300,
          ),
        ],
      ),
    );
  }
}
