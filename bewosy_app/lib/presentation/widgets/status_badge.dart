import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Status badge
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status.toUpperCase()) {
      'CONFIRMED' || 'PAID' || 'ACCEPTED' => (
          AppColors.success,
          AppColors.successLight
        ),
      'DRAFT' || 'SENT' => (AppColors.info, AppColors.infoLight),
      'OVERDUE' ||
      'CANCELLED' ||
      'REJECTED' => (AppColors.error, AppColors.errorLight),
      'PARTIAL' => (AppColors.warning, AppColors.warningLight),
      _ => (AppColors.navy500, AppColors.navy50),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
