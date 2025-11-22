// This file is kept for backward compatibility
// All functionality has been moved to UnifiedDiffDialog
export '../../../core/diff/diff_parser.dart' show DiffParser, DiffLine, DiffLineType;
export '../../../shared/dialogs/unified_diff_dialog.dart' show showUnifiedDiffDialog;

// Alias for backward compatibility
import '../../../shared/dialogs/unified_diff_dialog.dart' as unified;
import 'package:flutter/material.dart';

Future<void> showDiffViewerDialog(
  BuildContext context, {
  required String filePath,
  bool staged = false,
}) {
  return unified.showUnifiedDiffDialog(context, filePath: filePath, staged: staged);
}
