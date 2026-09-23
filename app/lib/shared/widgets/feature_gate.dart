import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/features/feature_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

/// Mirrors the React FeatureGate — blocks a screen's content when the Super
/// Admin has switched its feature off (or restricted it to Premium and this
/// business is on Free). The backend enforces the same key on every write
/// via bewosai.permissions.require_feature; this just keeps the UI from
/// showing a screen whose API calls would 403.
class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;

  /// Also require this staff permission ([module] / [action], e.g. 'sales' /
  /// 'view') - a staff member the owner hasn't given the module to sees a
  /// "no access" screen instead. The server refuses their requests regardless.
  final String? module;
  final String action;

  const FeatureGate({super.key, required this.feature, required this.child, this.module, this.action = 'view'});

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureProvider>();
    final business = context.watch<AuthProvider>().currentBusiness;
    if (module != null && business != null && !business.can(module!, action)) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _NoAccess(),
          ),
        ),
      );
    }
    if (features.loaded && !features.isEnabled(feature)) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This feature is currently unavailable',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "It's been switched off for your plan, or is temporarily disabled by the platform admin.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return child;
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(28)),
          child: Icon(Icons.lock_outline, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        const Text(
          "You don't have access to this",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "The business owner hasn't turned this on for your account. Ask them to enable it if you need it.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
