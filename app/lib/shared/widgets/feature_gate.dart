import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/features/feature_provider.dart';
import '../../core/theme/app_colors.dart';

/// Mirrors the React FeatureGate — blocks a screen's content when the Super
/// Admin has switched its feature off (or restricted it to Premium and this
/// business is on Free). The backend enforces the same key on every write
/// via bewosai.permissions.require_feature; this just keeps the UI from
/// showing a screen whose API calls would 403.
class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;

  const FeatureGate({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureProvider>();
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
