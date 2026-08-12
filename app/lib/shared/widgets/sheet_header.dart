import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Standard header row for every "quick entry" bottom sheet (Add Party, Add
/// Product, New Sale, etc.): a back button to dismiss the sheet on the
/// left, the sheet's title in the middle, and the tappable app logo on the
/// right, so there's always a one-tap way back to the Dashboard even from a
/// form stacked inside a modal — these sheets are frequently the very first
/// thing a user sees (e.g. shortcuts that open with the sheet already up),
/// so this is their only visible navigation until they act on it.
///
/// Deliberately doesn't reuse [HomeLogoButton] as-is: that widget only calls
/// `context.go('/dashboard')`, which updates the page underneath but leaves
/// this sheet visually open on top of it since the sheet is a separate
/// Navigator overlay. Popping the sheet first avoids that stuck-open state.
class SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const SheetHeader({super.key, required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    final business = context.watch<AuthProvider>().currentBusiness;
    final initial = business?.name.isNotEmpty == true ? business!.name[0].toUpperCase() : '?';

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          color: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).maybePop();
            context.go('/dashboard');
          },
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.orangeLight,
            child: Text(
              initial,
              style: const TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
