import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../../core/utils/file_launcher.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/logger_service.dart';

/// Temporary implementation: Opens PDF in external viewer
///
/// TODO: Replace with in-app PDF viewer once pdfx Windows build issues are resolved
/// Previous implementation used pdfx for in-app viewing with pagination controls
///
/// Related:
/// - pdfx package removed due to Windows CMake build failures (PDFium compatibility)
/// - Workaround: Open PDFs in system default viewer
/// - Future: Evaluate alternatives (pdfrx, syncfusion_flutter_pdfviewer, etc.)
Future<void> showPdfViewerDialog(
  BuildContext context, {
  required String filePath,
}) async {
  Logger.info('Opening PDF externally: $filePath');

  final fileName = path.basename(filePath);

  // Show info notification that PDF will open externally
  if (context.mounted) {
    NotificationService.showInfo(
      context,
      'Opening "$fileName" in external PDF viewer...',
    );
  }

  // Open the PDF in external application
  final success = await FileLauncher.openFileExternally(filePath);

  if (!success && context.mounted) {
    // Show error notification if opening failed
    NotificationService.showError(
      context,
      'Failed to open PDF file: $fileName\n\nPlease ensure you have a PDF viewer installed.',
    );
    Logger.error('Failed to open PDF externally: $filePath', null);
  }
}
