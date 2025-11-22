import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Base component for all card patterns in the app.
///
/// Provides unified selection behavior with elevation and borders:
/// - Normal state (elevation: 2, no border)
/// - Hover state (elevation: 4, no border)
/// - Multi-selected state (elevation: 4, secondary border 2px)
/// - Selected state (elevation: 8, primary border 3px)
///
/// Example usage:
/// ```dart
/// BaseCard(
///   header: Padding(
///     padding: const EdgeInsets.all(AppTheme.paddingM),
///     child: TitleLargeLabel('Card Header'),
///   ),
///   content: ListView(
///     children: [
///       ListTile(title: BodyMediumLabel('Item 1')),
///       ListTile(title: BodyMediumLabel('Item 2')),
///     ],
///   ),
///   footer: Padding(
///     padding: const EdgeInsets.all(AppTheme.paddingM),
///     child: Row(
///       mainAxisAlignment: MainAxisAlignment.end,
///       children: [
///         TextButton(onPressed: () {}, child: Text('Cancel')),
///         ElevatedButton(onPressed: () {}, child: Text('Save')),
///       ],
///     ),
///   ),
///   isSelected: true,
///   onTap: () => print('Card tapped'),
/// )
/// ```
class BaseCard extends StatefulWidget {
  const BaseCard({
    super.key,
    required this.content,
    this.header,
    this.footer,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.isSelectable = true,
    this.customBorderColor,
    this.customBackgroundColor,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.paddingL),
  });

  /// Main content area (required) - typically scrollable
  final Widget content;

  /// Header widget (optional) - displayed above content
  final Widget? header;

  /// Footer widget (optional) - displayed below content
  final Widget? footer;

  /// Whether this card is currently selected (primary selection)
  final bool isSelected;

  /// Whether this card is part of a multi-selection (secondary selection)
  final bool isMultiSelected;

  /// Whether this card can be selected/tapped
  final bool isSelectable;

  /// Custom border color to override theme colors (optional)
  /// Useful for workspace-specific colors
  final Color? customBorderColor;

  /// Custom background color when selected (optional)
  final Color? customBackgroundColor;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Internal padding for the content
  final EdgeInsets padding;

  @override
  State<BaseCard> createState() => _BaseCardState();
}

class _BaseCardState extends State<BaseCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine background color using Material Design 3 surface tones
    Color? backgroundColor;
    if (widget.isSelected) {
      // Selected state: use secondaryContainer for emphasis
      backgroundColor = widget.customBackgroundColor ?? colorScheme.secondaryContainer;
    } else if (widget.isMultiSelected) {
      // Multi-selected state: use tertiaryContainer
      backgroundColor = widget.customBackgroundColor ?? colorScheme.tertiaryContainer;
    } else if (_isHovered && widget.isSelectable) {
      // Hover state: use surfaceContainerHighest
      backgroundColor = colorScheme.surfaceContainerHighest;
    } else {
      // Normal state: use surfaceContainerHigh
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    // Determine border using Material Design 3 outline colors
    BoxBorder? border;
    if (widget.isSelected) {
      // Selected: use onSecondaryContainer for border
      border = Border.all(
        color: widget.customBorderColor ?? colorScheme.onSecondaryContainer,
        width: 2,
      );
    } else if (widget.isMultiSelected) {
      // Multi-selected: use onTertiaryContainer for border
      border = Border.all(
        color: colorScheme.onTertiaryContainer,
        width: 2,
      );
    } else {
      // Normal state: use outline variant
      border = Border.all(
        color: colorScheme.outlineVariant,
        width: 1,
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
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: colorScheme.onSurface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header section
                  if (widget.header != null) ...[
                    widget.header!,
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                  ],

                  // Content section (main area)
                  Flexible(
                    child: Padding(
                      padding: widget.padding,
                      child: widget.content,
                    ),
                  ),

                  // Footer section
                  if (widget.footer != null) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
