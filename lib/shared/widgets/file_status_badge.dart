import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;

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
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      // The badge states its own foreground and the code reads it, rather than
      // the two of them naming the same `Color` twice. [color] itself stays a
      // `Color` for now on purpose: it paints the wash behind the code as well
      // as the code, and until the badge is `surfaces.badge` at P3d there is no
      // contract member that can tint a surface from a `Tone` — a half-migrated
      // badge whose text is a meaning and whose fill is still a value would be
      // two names for one thing.
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: BaseLabel(code, role: TextRole.micro),
      ),
    );
  }
}
