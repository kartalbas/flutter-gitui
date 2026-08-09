import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show Inset, Proximity, TextRole;

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
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

  /// Whether the tree rendering this row holds keyboard focus.
  ///
  /// The tree is a single Tab stop with a roving highlight: while it is
  /// focused the selected row wears a focus ring on top of its tinted
  /// background, and while focus lives elsewhere the muted tinted background
  /// remains alone. Defaults to true so a row outside a focus-aware tree
  /// keeps the full treatment.
  final bool containerHasFocus;

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
    this.containerHasFocus = true,
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
          // Left alone deliberately. The leading edge is the row's own inset
          // plus one indent per level of the tree, and how tall a tree row is
          // is the point of a tree - neither is something the inset rungs can
          // say, and rounding either would change how much of the tree fits
          // on screen. See the P3d report.
          padding: EdgeInsets.only(
            left: depth * indentPerLevel + AppTheme.paddingS,
            right: AppTheme.paddingS,
            top: AppTheme.paddingXS,
            bottom: AppTheme.paddingXS,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
          ),
          // The focus ring, painted in the foreground so it costs no layout:
          // a decoration border would inset the dense row content by its
          // width every time focus moves. It appears only while the tree
          // itself holds keyboard focus; an unfocused selection keeps the
          // muted tinted background alone.
          foregroundDecoration: isSelected && widget.containerHasFocus
              ? BoxDecoration(
                  border: Border.all(
                    color: colorScheme.onPrimaryContainer,
                    width: 2,
                  ),
                )
              : null,
          // A selected row swaps its container for a tonal colour, so the row
          // publishes the foreground that pairs with it and everything inside
          // reads that instead of restating it. The row's name used to carry
          // the pairing itself, which is Material's on-colour model
          // (`docs/SKIN-CONTRACT-MEMBERS.md` §10.2) written out in application
          // code — and a row where only some children remember to restate it is
          // how half a selected row ends up at 4.13 : 1.
          child: DefaultTextStyle.merge(
            style: isSelected
                ? TextStyle(color: colorScheme.onPrimaryContainer)
                : null,
            child: Row(
              children: [
                // Optional leading widget (e.g., checkbox)
                if (leadingWidget != null) ...[
                  leadingWidget,
                  // A checkbox and the row it ticks are two halves of one
                  // thing, touching.
                  const BaseGap(Proximity.hairline),
                ],

                // Expand/collapse control for directories, kept in the layout
                // and hidden on a file row.
                //
                // A file used to reserve the caret's place with a number
                // copied FROM the caret, and the copy had gone stale: the
                // reservation was 16 - the caret's GLYPH - while the caret
                // itself measures its glyph plus the `Inset.hairline` it sits
                // in. Files therefore sat 4 px to the left of the folders they
                // hang under and their rows stood 1 px shorter, which is the
                // opposite of what the number was there to do. Reserving the
                // control ITSELF cannot go stale and needs no number at all:
                // the place a file keeps is whatever that skin's caret plus
                // that skin's hairline inset comes to, so the columns line up
                // in every language rather than in Material by coincidence.
                // Hidden this way the caret is also out of the hit test, so a
                // click in a file's caret column still reaches the row.
                Visibility(
                  visible: node.isDirectory,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: GestureDetector(
                    onTap: onExpandToggle ?? onTap,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      // The caret reaches as close to the edge of its own tap
                      // target as it can: the row's height is the point.
                      child: BaseInset(
                        all: Inset.hairline,
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
                  ),
                ),

                // The expand control and the mark naming the node are two
                // halves of one row, touching.
                const BaseGap(Proximity.hairline),

                // File/folder icon.
                //
                // The accent on a directory is a foreground and it still names
                // Material's primary role, deliberately, because nothing in
                // the vocabulary can carry this mark yet. Three things block it
                // once and each is a rule this programme learned the hard way:
                // the size is 18, which is between `ControlScale.compact` (16)
                // and `normal` (20), so naming a rung would resize every row
                // of every tree in the app; the glyph is a Phosphor BOLD
                // constant and `IconRole` re-decides weight inside the skin,
                // so converting drops the stroke silently; and the colour is a
                // three-way choice that ends in a caller-supplied
                // `fileIconColor`, which one `Tone` cannot express. The whole
                // mark - glyph, size and colour together - belongs to the tree
                // row member and moves in P5 as one piece.
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
                            (isSelected
                                ? colorScheme.onPrimaryContainer
                                : null)),
                ),

                // The mark and the name it stands for are two parts of one
                // statement.
                const BaseGap(Proximity.related),

                // File name. One line, because a tree row is a row: a name
                // that wrapped would push every row below it down the panel.
                Expanded(
                  child: BaseLabel(node.name, role: TextRole.body, maxLines: 1),
                ),

                // Optional trailing widget (e.g., status badge, menu)
                if (trailingWidget != null) ...[
                  // The name and what the row says about it are two parts of
                  // one statement.
                  const BaseGap(Proximity.related),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
