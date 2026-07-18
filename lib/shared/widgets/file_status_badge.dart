import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';

/// A badge widget that displays a file status code with color coding.
///
/// Used to show git status indicators like 'M' for modified, 'A' for added, etc.
class FileStatusBadge extends StatelessWidget {
  /// The status code to display (e.g., 'M', 'A', 'D')
  final String code;

  /// The color for the badge background and text
  final Color color;

  /// Whether the parent item is selected (affects background opacity)
  final bool isSelected;

  const FileStatusBadge({
    super.key,
    required this.code,
    required this.color,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingXS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.paddingXS),
      ),
      child: LabelSmallLabel(
        code,
        color: color,
      ),
    );
  }
}
