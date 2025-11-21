import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../models/tree_node.dart';

/// A base tree item widget that handles common tree item rendering patterns.
///
/// This widget provides the standard structure for tree items including:
/// - Depth-based indentation
/// - Selection highlighting
/// - Expand/collapse icons for directories
/// - Folder/file icons
/// - Name display with overflow handling
///
/// Customization is provided through:
/// - [leadingWidget] - Widget to show before the expand icon (e.g., checkbox)
/// - [trailingWidget] - Widget to show after the name (e.g., status badge, menu)
/// - [fileIcon] - Custom icon for files (defaults to generic file icon)
/// - [fileIconColor] - Custom color for the file icon
class BaseTreeItem extends StatelessWidget {
  /// The tree node to render
  final TreeNodeMixin node;

  /// The depth of this node in the tree (used for indentation)
  final int depth;

  /// Whether this item is currently selected
  final bool isSelected;

  /// Callback when the item is tapped
  final VoidCallback? onTap;

  /// Callback when the item is double-tapped
  final VoidCallback? onDoubleTap;

  /// Callback when the expand/collapse icon is tapped
  final VoidCallback? onExpandToggle;

  /// Optional widget to display before the expand icon (e.g., checkbox)
  final Widget? leadingWidget;

  /// Optional widget to display after the name (e.g., status badge, popup menu)
  final Widget? trailingWidget;

  /// Custom icon for files (defaults to generic file icon)
  final IconData? fileIcon;

  /// Custom color for the file icon
  final Color? fileIconColor;

  /// Indentation per depth level
  final double indentPerLevel;

  const BaseTreeItem({
    super.key,
    required this.node,
    required this.depth,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onExpandToggle,
    this.leadingWidget,
    this.trailingWidget,
    this.fileIcon,
    this.fileIconColor,
    this.indentPerLevel = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: EdgeInsets.only(
            left: depth * indentPerLevel + AppTheme.paddingS,
            right: AppTheme.paddingS,
            top: AppTheme.paddingXS,
            bottom: AppTheme.paddingXS,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
          ),
          child: Row(
            children: [
              // Optional leading widget (e.g., checkbox)
              if (leadingWidget != null) ...[
                leadingWidget!,
                const SizedBox(width: AppTheme.paddingXS),
              ],

              // Expand/collapse icon for directories
              if (node.isDirectory)
                GestureDetector(
                  onTap: onExpandToggle ?? onTap,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        node.isExpanded
                            ? PhosphorIconsRegular.caretDown
                            : PhosphorIconsRegular.caretRight,
                        size: 16,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: AppTheme.paddingM),

              const SizedBox(width: AppTheme.paddingXS),

              // File/folder icon
              Icon(
                node.isDirectory
                    ? (node.isExpanded
                        ? PhosphorIconsBold.folderOpen
                        : PhosphorIconsBold.folder)
                    : (fileIcon ?? PhosphorIconsBold.file),
                size: 18,
                color: node.isDirectory
                    ? colorScheme.primary
                    : (fileIconColor ??
                        (isSelected ? colorScheme.onPrimaryContainer : null)),
              ),

              const SizedBox(width: AppTheme.paddingS),

              // File name
              Expanded(
                child: BodyMediumLabel(
                  node.name,
                  color: isSelected ? colorScheme.onPrimaryContainer : null,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Optional trailing widget (e.g., status badge, menu)
              if (trailingWidget != null) ...[
                const SizedBox(width: AppTheme.paddingS),
                trailingWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
