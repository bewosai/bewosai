import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Confirm delete dialog
Future<bool> showDeleteConfirm(BuildContext context,
    {bool permanent = false}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(permanent ? 'Permanent Delete?' : 'Delete?'),
          content: Text(permanent
              ? 'This will permanently delete the record. This cannot be undone.'
              : 'Are you sure you want to delete? It will go to Recycle Bin.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    permanent ? AppColors.error : AppColors.orange,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(permanent ? 'Delete Forever' : 'Delete'),
            ),
          ],
        ),
      ) ??
      false;
}
