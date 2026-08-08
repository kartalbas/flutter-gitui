import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';

import '../../../../shared/components/base_label.dart';
import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced image viewer dialog with zoom and pan
class ImageViewerDialog extends StatelessWidget {
  final String filePath;

  const ImageViewerDialog({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(filePath);
    final file = File(filePath);
    final theme = Theme.of(context);

    // The three scrim fills this used to hand `BaseViewerDialog` are gone.
    // They painted the dialog, its header and its footer near-black while the
    // component paired the header's text with `colorScheme.onPrimary` — black
    // ink on a black header, 1.06 : 1 in six of the ten dark schemes and
    // 1.61 : 1 in light. A fill and the ink that pairs with it are one
    // decision, and this screen was taking half of it; the chrome is now the
    // theme's, which pairs itself. The image still sits on a dark backdrop
    // below, which is `PhotoView`'s own and is where the darkness was
    // actually doing work.
    return BaseViewerDialog(
      icon: IconRole.image,
      title: 'Image Viewer',
      subtitle: fileName,
      content: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: BoxDecoration(color: theme.colorScheme.scrim),
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
            Icon(
              PhosphorIconsRegular.mouseSimple,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppTheme.paddingS),
            // The caption is secondary to the image above it. The 0.7 was
            // that statement said a second time, in a number.
            const BaseLabel(
              'Scroll to zoom • Drag to pan',
              role: TextRole.detail,
              tone: Tone.muted,
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
