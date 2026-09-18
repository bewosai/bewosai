import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../router/dashboard_route.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Business-avatar "logo" shown in every pushed screen's AppBar — tapping it
/// jumps straight back to the Dashboard, same as the one already on the
/// Dashboard tab's own AppBar.
class HomeLogoButton extends StatelessWidget {
  const HomeLogoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final business = context.watch<AuthProvider>().currentBusiness;
    final initial = business?.name.isNotEmpty == true ? business!.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(dashboardLocation()),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.orangeLight,
          child: Text(
            initial,
            style: const TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
