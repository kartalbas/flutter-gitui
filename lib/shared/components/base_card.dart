import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Base component for all card patterns in the app.
///
/// Renders flat (no shadow elevation) and communicates state through
/// Material 3 tonal surfaces and outline borders:
/// - Normal state (surfaceContainerHigh, 1px outlineVariant border)
/// - Hover state (surfaceContainerHighest, 1px outlineVariant border)
/// - Multi-selected state (tertiaryContainer, 2px onTertiaryContainer border)
/// - Selected state (secondaryContainer, 2px onSecondaryContainer border)
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
    this.containerHasFocus = true,
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

  /// Whether the collection rendering this card holds keyboard focus.
  ///
  /// A card grid is a single Tab stop with a roving highlight: while it is
  /// focused the selected card wears its focus ring (tinted background plus
  /// emphasized border), and while focus lives elsewhere the selection keeps
  /// the tinted background with the resting outline — still clearly the
  /// selection, no longer claiming the keyboard. Defaults to true so a card
  /// outside a focus-aware collection keeps the full treatment.
  final bool containerHasFocus;

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
      backgroundColor =
          widget.customBackgroundColor ?? colorScheme.secondaryContainer;
    } else if (widget.isMultiSelected) {
      // Multi-selected state: use tertiaryContainer
      backgroundColor =
          widget.customBackgroundColor ?? colorScheme.tertiaryContainer;
    } else if (_isHovered && widget.isSelectable) {
      // Hover state: use surfaceContainerHighest
      backgroundColor = colorScheme.surfaceContainerHighest;
    } else {
      // Normal state: use surfaceContainerHigh
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    // Determine border using Material Design 3 outline colors. The
    // emphasized border is the focus ring: it shows its on-container color
    // only while the card's collection holds keyboard focus. An unfocused
    // selection keeps the tinted background behind the resting outline color
    // (at the same width, so the content does not shift when focus moves) —
    // still clearly the selection, no longer claiming the keyboard.
    BoxBorder? border;
    if (widget.isSelected) {
      // Selected: use onSecondaryContainer for border
      border = Border.all(
        color: widget.containerHasFocus
            ? (widget.customBorderColor ?? colorScheme.onSecondaryContainer)
            : colorScheme.outlineVariant,
        width: 2,
      );
    } else if (widget.isMultiSelected) {
      // Multi-selected: use onTertiaryContainer for border
      border = Border.all(
        color: widget.containerHasFocus
            ? colorScheme.onTertiaryContainer
            : colorScheme.outlineVariant,
        width: 2,
      );
    } else {
      // Normal state: use outline variant
      border = Border.all(color: colorScheme.outlineVariant, width: 1);
    }

    return MouseRegion(
      onEnter: widget.isSelectable
          ? (_) => setState(() => _isHovered = true)
          : null,
      onExit: widget.isSelectable
          ? (_) => setState(() => _isHovered = false)
          : null,
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
