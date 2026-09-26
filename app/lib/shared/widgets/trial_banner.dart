import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/licensing/license_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/billing/presentation/screens/upgrade_plan_screen.dart';

/// "Free trial: N days left · Go Premium" — shown on the dashboard only while
/// the business is still on its free trial with no license or coupon. Tapping
/// it opens the Upgrade page, where a coupon code activates Premium.
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<LicenseProvider>().status;
    if (status == null || !status.isOnFreeTrial) return const SizedBox.shrink();
    final days = status.trialDaysLeft();
    final label = days == null
        ? 'You are on the free trial'
        : days == 0
            ? 'Your free trial ends today'
            : 'Free trial: $days day${days == 1 ? '' : 's'} left';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UpgradePlanScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: AppColors.orangeDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.orangeDark),
                  ),
                ),
                const Text(
                  'Go Premium',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.orangeDark),
                ),
                const Icon(Icons.chevron_right, color: AppColors.orangeDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
