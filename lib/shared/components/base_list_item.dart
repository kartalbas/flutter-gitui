import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../shared/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import '../widgets/double_tap_tracker.dart';
import 'base_animated_widgets.dart';
import 'base_menu_item.dart';

/// Base component for all list item patterns in the app.
///
/// The row reproduces Material 3 list-item geometry as the SDK's own
/// `ListTile` renders it (flutter/lib/src/material/list_tile.dart:1818-1860):
/// a 56 dp minimum tile height, a 16 dp leading edge, a 24 dp trailing edge,
/// a 16 dp gap after the leading slot, a `bodyLarge` title, an
/// `onSurfaceVariant` icon theme, and hover/press painted as Material state
/// layers by an [InkWell] over an [Ink] tile rather than as container-color
/// swaps.
///
/// Selection is the app's own layer on top of that geometry:
/// - Normal state (transparent tile)
/// - Selected state (secondaryContainer + onSecondaryContainer ring)
/// - Multi-selected state (tertiaryContainer + onTertiaryContainer ring)
///
/// The row's text and icon colors follow whichever tile is painted, through
/// [readableForeground], so a selected row never leaves its title on a role
/// chosen against the unselected tile. That covers every slot — content,
/// badge and trailing for text, and the row's [IconTheme] for glyphs, which
/// are held to the 3 : 1 non-text threshold rather than 4.5 : 1. The pairs are
/// asserted per slot, per state and per brightness by
/// packages/gitui_skin_material/test/conformance/a11y/component_colors_contrast_test.dart.
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
///     MenuAction(
///       label: 'Edit',
///       icon: PhosphorIconsRegular.pencil,
///       onPressed: () => _edit(),
///     ),
///     MenuAction(
///       label: 'Delete',
///       icon: PhosphorIconsRegular.trash,
///       role: MenuActionRole.destructive,
///       onPressed: () => _delete(),
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
    this.containerHasFocus = true,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.padding = const EdgeInsetsDirectional.only(
      start: AppTheme.paddingM,
      end: AppTheme.paddingL,
      top: AppTheme.paddingM,
      bottom: AppTheme.paddingM,
    ),
  });

  /// Smallest height a row may occupy, the Material 3 one-line list-item
  /// height (`_defaultTileHeight`,
  /// flutter/lib/src/material/list_tile.dart:1509). Taller content grows the
  /// row, exactly as it does in `ListTile`.
  static const double minTileHeight = 56.0;

  /// Main content area (required)
  final Widget content;

  /// Leading widget (optional) - typically an icon
  final Widget? leading;

  /// Trailing widget (optional) - typically action buttons
  final Widget? trailing;

  /// Badge/status indicator (optional)
  final Widget? badge;

  /// The entries of the row's three-dot menu, as data (optional).
  ///
  /// When this is non-empty the row grows its own overflow button, combined
  /// with [trailing] if that is present too.
  ///
  /// The entries are [MenuEntry] data rather than Material `PopupMenuEntry`
  /// widgets. That is the whole point of the type: the widget form welded
  /// Material's menu *classes* into this component's public signature, where
  /// one design language rejects them at compile time and another accepts them
  /// and renders Material rows inside its own menu — see [MenuEntry] for the
  /// measurement. What a skin needs is the label, the glyph, the callback and
  /// the role, and that is exactly what this carries.
  final List<MenuEntry>? contextMenuItems;

  /// Whether this item is currently selected (primary selection)
  final bool isSelected;

  /// Whether this item is part of a multi-selection (secondary selection)
  final bool isMultiSelected;

  /// Whether this item can be selected/tapped
  final bool isSelectable;

  /// Whether the collection rendering this item holds keyboard focus.
  ///
  /// A collection is a single Tab stop with a roving highlight, so the
  /// highlight has two strengths: while the collection is focused the selected
  /// item wears its focus ring (tinted background plus border), and while
  /// focus lives elsewhere it keeps only the muted tinted background — still
  /// clearly the selection, no longer claiming the keyboard. Defaults to true
  /// so an item outside a focus-aware collection keeps the full treatment.
  final bool containerHasFocus;

  /// Callback when item is tapped
  final VoidCallback? onTap;

  /// Callback when item is double-tapped
  final VoidCallback? onDoubleTap;

  /// Callback when item is right-clicked (context menu)
  final Function(Offset)? onSecondaryTap;

  /// Internal padding
  final EdgeInsetsGeometry padding;

  @override
  State<BaseListItem> createState() => _BaseListItemState();
}

class _BaseListItemState extends State<BaseListItem> {
  // Rows must react on the press, so the double click is recognised from the
  // interval between taps rather than through the detector's onDoubleTap,
  // which would hold every single tap for 300 ms. Each row has its own state
  // and therefore its own tracker, so `this` identifies the row. See
  // DoubleTapTracker.
  final DoubleTapTracker _tapTracker = DoubleTapTracker();

  void _handleTap() {
    if (!widget.isSelectable) return;
    final isDoubleTap = _tapTracker.registerTap(this, DateTime.now());
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
    final l10n = AppLocalizations.of(context)!;

    // Build effective trailing widget (combine trailing + context menu if needed)
    Widget? effectiveTrailing = widget.trailing;
    final List<MenuEntry>? menuEntries = widget.contextMenuItems;
    if (menuEntries != null && menuEntries.isNotEmpty) {
      // The menu carries the position of the chosen entry as its value and
      // dispatches through `onSelected`, so the callback runs once the menu
      // route has completed rather than in the middle of closing it — which
      // matters here, because most of these callbacks open a dialog.
      final menuButton = BasePopupMenuButton<int>(
        icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
        tooltip: l10n.moreActions,
        itemBuilder: (context) => materialMenuEntries(context, menuEntries),
        onSelected: (int index) => dispatchMenuEntry(menuEntries, index),
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

    // Determine background color using Material Design 3 surface tones. Hover
    // is deliberately absent here: it is a state layer the InkWell paints on
    // top of the Ink tile, so it stays visible on a selected row instead of
    // being hidden under an opaque selection color.
    Color? backgroundColor;
    if (widget.isSelected) {
      // Selected state: use secondaryContainer for emphasis
      backgroundColor = colorScheme.secondaryContainer;
    } else if (widget.isMultiSelected) {
      // Multi-selected state: use tertiaryContainer
      backgroundColor = colorScheme.tertiaryContainer;
    }

    // The row's foreground follows the tile the row actually paints. This is
    // the same defect BaseCard carried: selection swaps the tile for a tonal
    // container while the title stays on `onSurface`, which is the role
    // chosen against the *unselected* tile — 4.13 : 1 on `secondaryContainer`
    // in the dark theme, under the 4.5 : 1 SC 1.4.3 asks of body text.
    // `readableForeground` takes the M3 pairing for the state and departs from
    // it only where the scheme's own on-role misses the threshold.
    //
    // A row that paints no tile publishes nothing of its own and inherits
    // instead, because "transparent" means the text sits on whatever is
    // behind the row — which is `onSurface` on a plain surface, and the
    // enclosing container's own foreground inside a selected BaseCard.
    final Color foregroundColor = backgroundColor == null
        ? DefaultTextStyle.of(context).style.color ?? colorScheme.onSurface
        : readableForeground(
            preferred: widget.isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onTertiaryContainer,
            background: backgroundColor,
            backgroundBase: colorScheme.surface,
          );

    // Icons are held to SC 1.4.11's 3 : 1 rather than to 4.5 : 1: a row's
    // glyphs are non-text UI. M3's list-item icon role is `onSurfaceVariant`
    // (list_tile.dart:1818-1860) and it stays exactly that wherever it clears
    // the threshold; on the dark theme's selected tile it measures 2.86 : 1,
    // so there the same fallback the label uses takes over. Without this the
    // leading glyph of a selected row was the one part of it still coloured
    // for the unselected tile.
    final Color iconColor = backgroundColor == null
        ? colorScheme.onSurfaceVariant
        : readableForeground(
            preferred: colorScheme.onSurfaceVariant,
            background: backgroundColor,
            backgroundBase: colorScheme.surface,
            minRatio: kWcagNonTextContrast,
          );

    // Determine border using Material Design 3 outline colors. The border is
    // the focus ring: it shows its on-container color only while the item's
    // collection holds keyboard focus. An unfocused selection paints the same
    // border in the background color — invisible, so the muted highlight is
    // the tinted background alone, and the row does not shift by the border
    // width when focus moves (a decoration border insets the content).
    BoxBorder? border;
    if (widget.isSelected) {
      border = Border.all(
        color: widget.containerHasFocus
            ? colorScheme.onSecondaryContainer
            : colorScheme.secondaryContainer,
        width: 2,
      );
    } else if (widget.isMultiSelected) {
      border = Border.all(
        color: widget.containerHasFocus
            ? colorScheme.onTertiaryContainer
            : colorScheme.tertiaryContainer,
        width: 2,
      );
    }

    final isInteractive =
        widget.isSelectable &&
        (widget.onTap != null || widget.onDoubleTap != null);

    return GestureDetector(
      // The secondary (right) button has no InkWell equivalent, so the
      // context-menu gesture keeps its own detector around the row.
      onSecondaryTapDown: widget.onSecondaryTap != null
          ? (details) => widget.onSecondaryTap!(details.globalPosition)
          : null,
      child: Stack(
        children: [
          InkWell(
            // Deliberately no onDoubleTap: registering one makes Flutter
            // withhold every single tap until the 300 ms double-tap window
            // closes.
            onTap: isInteractive ? _handleTap : null,
            // A list is a single Tab stop with a roving highlight
            // (lib/shared/widgets/keyboard_navigable_view.dart:520-524), so an
            // individual row must never become a Tab stop of its own; the
            // focus indication is the ring driven by [containerHasFocus].
            // Registered as LIST-002.
            canRequestFocus: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: BaseListItem.minTileHeight,
              ),
              // Ink, not Container: the tile color has to be painted INTO the
              // ancestor Material's ink layer so the hover and press state
              // layers land on top of it. A Container would paint over them
              // and a selected row would lose its hover feedback. This is how
              // ListTile paints its own tileColor (list_tile.dart:999-1003).
              child: Ink(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: border,
                ),
                padding: widget.padding,
                // The tile's foreground is published to the whole row, not
                // just to the content slot. A badge or a trailing label sits
                // on the same tile as the title, and wrapping only `content`
                // left them on the ambient `onSurface`: a label in the
                // trailing slot of a selected row measured 4.13 : 1 in the
                // dark theme, the exact failure this component's content slot
                // had. Only the colour is merged here so each slot keeps its
                // own type role — the content's `bodyLarge`, a badge's
                // `labelSmall` — and only the colour moves with the tile.
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foregroundColor),
                  child: IconTheme.merge(
                    data: IconThemeData(color: iconColor),
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
                            style: theme.textTheme.bodyLarge!.copyWith(
                              color: foregroundColor,
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
                ),
              ),
            ),
          ),
          // Subtle divider for visual separation, inset to the row's leading
          // edge. It is drawn INSIDE the tile's own height rather than
          // stacked below it, so a row's pitch equals its tile height: lists
          // that allocate a fixed extent per row (KeyboardNavigableListView's
          // itemExtent, which the roving highlight needs to scroll a row into
          // view) would otherwise be one pixel short of every row.
          PositionedDirectional(
            start: AppTheme.paddingM,
            end: 0,
            bottom: 0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
