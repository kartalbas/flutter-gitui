import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../models/tree_node.dart';
import 'double_tap_tracker.dart';

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
class BaseTreeItem extends StatefulWidget {
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
  State<BaseTreeItem> createState() => _BaseTreeItemState();
}

class _BaseTreeItemState extends State<BaseTreeItem> {
  // Rows must react on the press, so the double click is recognised from the
  // interval between taps instead of through the detector's onDoubleTap, which
  // would hold every single tap for 300 ms. See DoubleTapTracker.
  final DoubleTapTracker _tapTracker = DoubleTapTracker();

  void _handleTap() {
    final isDoubleTap = _tapTracker.registerTap(widget.node, DateTime.now());
    if (isDoubleTap && widget.onDoubleTap != null) {
      widget.onDoubleTap!();
      return;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final node = widget.node;
    final isSelected = widget.isSelected;
    final depth = widget.depth;
    final indentPerLevel = widget.indentPerLevel;
    final leadingWidget = widget.leadingWidget;
    final trailingWidget = widget.trailingWidget;
    final fileIcon = widget.fileIcon;
    final fileIconColor = widget.fileIconColor;
    final onTap = widget.onTap;
    final onExpandToggle = widget.onExpandToggle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Deliberately no onDoubleTap: registering one makes Flutter withhold
        // every single tap until the 300 ms double-tap window closes.
        onTap: _handleTap,
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
                leadingWidget,
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
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
