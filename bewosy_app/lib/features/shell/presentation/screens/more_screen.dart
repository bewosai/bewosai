import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final business = auth.currentBusiness;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
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
            const SizedBox(height: 20),
            const SectionHeader(title: 'Business'),
            const SizedBox(height: 10),
            AppSectionCard(
              children: [
                _tile(
                  context,
                  Icons.point_of_sale_outlined,
                  'Quick POS',
                  () => context.push('/pos'),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.receipt_outlined,
                  'Expenses',
                  () => context.push('/expenses'),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.account_balance_outlined,
                  'Banking',
                  () => context.push('/banking'),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.bar_chart_outlined,
                  'Reports',
                  () => context.push('/reports'),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.badge_outlined,
                  'Staff',
                  () => context.push('/staff'),
                ),
              ],
            ),
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
                  'Settings',
                  () => context.push('/settings'),
                ),
                _divider(),
                _tile(
                  context,
                  Icons.delete_outline,
                  'Recycle Bin',
                  () => context.push('/recycle-bin'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppSectionCard(
              children: [
                _tile(
                  context,
                  Icons.logout,
                  'Logout',
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
