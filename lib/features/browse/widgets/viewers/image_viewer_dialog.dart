import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';

import '../../../../shared/components/base_label.dart';
import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced image viewer dialog with zoom and pan
class ImageViewerDialog extends StatelessWidget {
  final String filePath;

  const ImageViewerDialog({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(filePath);
    final file = File(filePath);
    final theme = Theme.of(context);

    return BaseViewerDialog(
      icon: PhosphorIconsRegular.image,
      title: 'Image Viewer',
      subtitle: fileName,
      backgroundColor: theme.colorScheme.scrim,
      headerBackgroundColor: theme.colorScheme.scrim.withValues(alpha: 0.7),
      footerBackgroundColor: theme.colorScheme.scrim.withValues(alpha: 0.7),
      content: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: BoxDecoration(
          color: theme.colorScheme.scrim,
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: filePath),
      ),
      footer: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.mouseSimple, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: AppTheme.paddingS),
            BodySmallLabel(
              'Scroll to zoom • Drag to pan',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show image viewer dialog
Future<void> showImageViewerDialog(
  BuildContext context, {
  required String filePath,
}) {
  return showDialog(
    context: context,
    builder: (context) => ImageViewerDialog(filePath: filePath),
  );
}

