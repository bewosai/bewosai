import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';

/// A square photo-attachment tile — pick from camera/gallery, preview,
/// remove. Used for any "attach a receipt/bill photo" field (Purchases'
/// bill image, Expenses' receipt image, ...) so the pattern only lives
/// in one place.
class ReceiptImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const ReceiptImagePicker({
    super.key,
    required this.imageFile,
    required this.imageUrl,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || (imageUrl?.isNotEmpty ?? false);
    if (!hasImage) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            color: AppColors.navy50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navy300),
          ),
          child: Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageFile != null
                ? Image.file(imageFile!, height: 90, width: 90, fit: BoxFit.cover)
                : Image.network(imageUrl!, height: 90, width: 90, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the camera/gallery chooser bottom sheet and returns the picked
/// file's path, or null if the user cancelled at either step.
Future<String?> pickReceiptImagePath(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600, maxHeight: 1600);
  return picked?.path;
}
