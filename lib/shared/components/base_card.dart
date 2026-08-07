import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Base component for all card patterns in the app.
///
/// This is the app's Material 3 **outlined card**: it renders flat (no shadow
/// elevation) behind a 1 px `outlineVariant` border, exactly like
/// `Card.outlined` (flutter/lib/src/material/card.dart:371-396), and reserves
/// the tonal containers for selection rather than for elevation:
/// - Normal state (surfaceContainerHigh, 1px outlineVariant border)
/// - Multi-selected state (tertiaryContainer, 2px onTertiaryContainer border)
/// - Selected state (secondaryContainer, 2px onSecondaryContainer border)
///
/// Hover and press are **not** container-color swaps but Material state
/// layers painted by the card's own [InkWell], so they read the same on a
/// resting card and on a selected one. See
/// test/conformance/components/base_card_conformance_test.dart.
///
/// The content's text color follows whichever of those containers is painted,
/// through [readableForeground], so a selection never leaves the label on a
/// role that was chosen against the unselected background. The pairs are
/// asserted per state and per brightness by
/// test/conformance/a11y/component_colors_contrast_test.dart.
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
class BaseCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine background color using Material Design 3 surface tones. Hover
    // is deliberately absent here: it is a state layer the InkWell below
    // paints on top of whichever container color the card is resting on, so
    // hovering a selected card is as visible as hovering a resting one.
    Color? backgroundColor;
    if (isSelected) {
      // Selected state: use secondaryContainer for emphasis
      backgroundColor = customBackgroundColor ?? colorScheme.secondaryContainer;
    } else if (isMultiSelected) {
      // Multi-selected state: use tertiaryContainer
      backgroundColor = customBackgroundColor ?? colorScheme.tertiaryContainer;
    } else {
      // Normal state: use surfaceContainerHigh
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    // The content's foreground follows the container the card actually
    // paints. Selection swaps that container for a tonal one, and a label left
    // on `onSurface` would keep the role chosen against the *unselected*
    // background: 4.13 : 1 on `secondaryContainer` in the dark theme, under
    // the 4.5 : 1 SC 1.4.3 asks of body text. `readableForeground` takes the
    // M3 pairing for the state and only departs from it where the scheme's own
    // on-role misses the threshold — which it does here, at 4.45 : 1.
    //
    // A [customBackgroundColor] is *not* one of those pairings, so it keeps
    // `onSurface` as the role to try: the colour comes from outside the
    // scheme — repository_card.dart passes `primary` at 10 %, workspace_card
    // .dart the workspace colour at 10 % — and `onSecondaryContainer` is the
    // on-role of a container this card is then not painting. Trying
    // `onSurface` and falling back only when it fails is what keeps a tinted
    // card reading like the surface it is a tint of.
    //
    // Both go through the rule against the colour the card *composites* to,
    // not against the colour it was handed: a 10 % tint is transparent, and
    // judging it by its own channels reads a pale lilac `primary` as a light
    // container in the dark theme and answers black. What a card is composited
    // over is `surface` — M3's role for what the application paints behind
    // everything, and the darkest of the surface tones the card can land on,
    // so the flattened colour is never assumed lighter than it really is.
    final Color foregroundColor = readableForeground(
      preferred: customBackgroundColor != null
          ? colorScheme.onSurface
          : isSelected
          ? colorScheme.onSecondaryContainer
          : isMultiSelected
          ? colorScheme.onTertiaryContainer
          : colorScheme.onSurface,
      background: backgroundColor,
      backgroundBase: colorScheme.surface,
    );

    // Determine border using Material Design 3 outline colors. The
    // emphasized border is the focus ring: it shows its on-container color
    // only while the card's collection holds keyboard focus. An unfocused
    // selection keeps the tinted background behind the resting outline color
    // (at the same width, so the content does not shift when focus moves) —
    // still clearly the selection, no longer claiming the keyboard.
    BoxBorder? border;
    if (isSelected) {
      // Selected: use onSecondaryContainer for border
      border = Border.all(
        color: containerHasFocus
            ? (customBorderColor ?? colorScheme.onSecondaryContainer)
            : colorScheme.outlineVariant,
        width: 2,
      );
    } else if (isMultiSelected) {
      // Multi-selected: use onTertiaryContainer for border
      border = Border.all(
        color: containerHasFocus
            ? colorScheme.onTertiaryContainer
            : colorScheme.outlineVariant,
        width: 2,
      );
    } else {
      // Normal state: use outline variant
      border = Border.all(color: colorScheme.outlineVariant, width: 1);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        // Ink children (list tiles, ink wells) paint their hover, focus
        // and pressed state layers on the nearest Material. Without one
        // inside the decorated box those layers land on a Material behind
        // the card's background and stay invisible — which keyboard
        // traversal exposes the moment a tile in a card receives focus.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isSelectable ? onTap : null,
            // A card collection is a single Tab stop with a roving highlight
            // (lib/shared/widgets/keyboard_navigable_view.dart:520-524), so
            // an individual card must never become a Tab stop of its own;
            // the focus indication is the emphasized border driven by
            // [containerHasFocus]. Registered as CARD-004.
            canRequestFocus: false,
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: foregroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header section
                  if (header != null) ...[
                    header!,
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                  ],

                  // Content section (main area)
                  Flexible(
                    child: Padding(padding: padding, child: content),
                  ),

                  // Footer section
                  if (footer != null) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    footer!,
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
