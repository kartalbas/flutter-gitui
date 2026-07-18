import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../shared/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import 'base_animated_widgets.dart';

/// Base component for all list item patterns in the app.
///
/// Provides unified selection behavior:
/// - Normal state
/// - Hover state (lighter background)
/// - Selected state (primary border + tinted background)
/// - Multi-selected state (secondary border + tinted background)
///
/// Example usage:
/// ```dart
/// BaseListItem(
///   leading: Icon(PhosphorIconsRegular.folder),
///   content: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: [
///       TitleMediumLabel('Title'),
///       BodySmallLabel('Subtitle'),
///     ],
///   ),
///   badge: Badge(label: Text('5')),
///   contextMenuItems: [
///     PopupMenuItem(
///       child: Row(
///         children: [
///           Icon(PhosphorIconsRegular.pencil),
///           SizedBox(width: 8),
///           BodyMediumLabel('Edit'),
///         ],
///       ),
///       onTap: () => _edit(),
///     ),
///     PopupMenuItem(
///       child: Row(
///         children: [
///           Icon(PhosphorIconsRegular.trash),
///           SizedBox(width: 8),
///           BodyMediumLabel('Delete'),
///         ],
///       ),
///       onTap: () => _delete(),
///     ),
///   ],
///   isSelected: true,
///   onTap: () => print('Tapped'),
/// )
/// ```
class BaseListItem extends StatefulWidget {
  const BaseListItem({
    super.key,
    required this.content,
    this.leading,
    this.trailing,
    this.badge,
    this.contextMenuItems,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.isSelectable = true,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.paddingL,
      vertical: AppTheme.paddingM,
    ),
  });

  /// Main content area (required)
  final Widget content;

  /// Leading widget (optional) - typically an icon
  final Widget? leading;

  /// Trailing widget (optional) - typically action buttons
  final Widget? trailing;

  /// Badge/status indicator (optional)
  final Widget? badge;

  /// Context menu items for three-dot menu (optional)
  /// If provided, automatically adds a PopupMenuButton with these items
  /// Combined with existing trailing widget if both are present
  final List<PopupMenuEntry<dynamic>>? contextMenuItems;

  /// Whether this item is currently selected (primary selection)
  final bool isSelected;

  /// Whether this item is part of a multi-selection (secondary selection)
  final bool isMultiSelected;

  /// Whether this item can be selected/tapped
  final bool isSelectable;

  /// Callback when item is tapped
  final VoidCallback? onTap;

  /// Callback when item is double-tapped
  final VoidCallback? onDoubleTap;

  /// Callback when item is right-clicked (context menu)
  final Function(Offset)? onSecondaryTap;

  /// Internal padding
  final EdgeInsets padding;

  @override
  State<BaseListItem> createState() => _BaseListItemState();
}

class _BaseListItemState extends State<BaseListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Build effective trailing widget (combine trailing + context menu if needed)
    Widget? effectiveTrailing = widget.trailing;
    if (widget.contextMenuItems != null && widget.contextMenuItems!.isNotEmpty) {
      final menuButton = BasePopupMenuButton(
        icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
        tooltip: l10n.moreActions,
        itemBuilder: (context) => widget.contextMenuItems!,
      );

      // Combine with existing trailing if present
      if (widget.trailing != null) {
        effectiveTrailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.trailing!,
            const SizedBox(width: AppTheme.paddingS),
            menuButton,
          ],
        );
      } else {
        effectiveTrailing = menuButton;
      }
    }

    // Determine background color using Material Design 3 surface tones
    Color? backgroundColor;
    if (widget.isSelected) {
      // Selected state: use secondaryContainer for emphasis
      backgroundColor = colorScheme.secondaryContainer;
    } else if (widget.isMultiSelected) {
      // Multi-selected state: use tertiaryContainer
      backgroundColor = colorScheme.tertiaryContainer;
    } else if (_isHovered && widget.isSelectable) {
      // Hover state: use surfaceContainerHighest
      backgroundColor = colorScheme.surfaceContainerHighest;
    }

    // Determine border using Material Design 3 outline colors
    BoxBorder? border;
    if (widget.isSelected) {
      // Selected: use onSecondaryContainer for border
      border = Border.all(
        color: colorScheme.onSecondaryContainer,
        width: 2,
      );
    } else if (widget.isMultiSelected) {
      // Multi-selected: use onTertiaryContainer for border
      border = Border.all(
        color: colorScheme.onTertiaryContainer,
        width: 2,
      );
    }

    return MouseRegion(
      onEnter: widget.isSelectable ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.isSelectable ? (_) => setState(() => _isHovered = false) : null,
      cursor: widget.isSelectable && widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.isSelectable ? widget.onTap : null,
        onDoubleTap: widget.isSelectable ? widget.onDoubleTap : null,
        onSecondaryTapDown: widget.onSecondaryTap != null
            ? (details) => widget.onSecondaryTap!(details.globalPosition)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                border: border,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              padding: widget.padding,
              child: Row(
                children: [
                  // Leading widget
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppTheme.paddingM),
                  ],

                  // Content area (expands to fill available space)
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      child: widget.content,
                    ),
                  ),

                  // Badge
                  if (widget.badge != null) ...[
                    const SizedBox(width: AppTheme.paddingS),
                    widget.badge!,
                  ],

                  // Trailing widget (or auto-generated three-dot menu)
                  if (effectiveTrailing != null) ...[
                    const SizedBox(width: AppTheme.paddingM),
                    effectiveTrailing,
                  ],
                ],
              ),
            ),
            // Subtle divider for visual separation
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.paddingL,
                top: AppTheme.paddingS,
              ),
              child: Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
