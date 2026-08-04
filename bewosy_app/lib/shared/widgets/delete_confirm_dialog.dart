import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  String title = 'Delete this item?',
  String message = 'This action cannot be undone.',
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
