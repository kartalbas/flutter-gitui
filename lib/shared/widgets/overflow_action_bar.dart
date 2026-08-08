import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show ControlScale, IconRole;

import '../components/base_animated_widgets.dart';
import '../components/base_button.dart';
import '../components/base_icon.dart';
import '../components/base_menu_item.dart';
import '../theme/app_theme.dart';

/// One action of a toolbar, as an icon button or as a menu entry.
class ToolbarAction {
  const ToolbarAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.variant = ButtonVariant.secondary,
  });

  /// The meaning of the action's mark; the skin chooses the glyph.
  final IconRole icon;

  /// Shown next to the icon once the action moves into the overflow menu,
  /// where an icon alone would be a guess.
  final String label;

  /// Shown on hover, and carrying the reason when the action is unavailable.
  final String tooltip;

  /// Null disables the action; it stays visible either way, because a toolbar
  /// that silently drops what it cannot do explains nothing.
  final VoidCallback? onPressed;

  /// Emphasis of the icon button while the action is visible. Defaults to the
  /// quiet secondary treatment every ordinary toolbar action uses; an action
  /// that is a standing signal rather than a command may raise it.
  final ButtonVariant variant;
}

/// How many actions fit before the overflow button is needed.
///
/// Returns the number to show as icons; the rest belong in the menu. When
/// everything fits, no slot is reserved for the overflow button - reserving one
/// unconditionally would push out an action that had room.
///
/// [availableWidth] is expected to be at least [itemExtent]: below that not
/// even the overflow button fits, and nothing can be shown at all. Callers give
/// the bar at least that much.
int visibleActionCount({
  required double availableWidth,
  required int actionCount,
  double itemExtent = OverflowActionBar.itemExtent,
  double spacing = OverflowActionBar.spacing,
  double menuExtent = OverflowActionBar.menuExtent,
}) {
  if (actionCount <= 0) return 0;

  // n items need n widths and n-1 gaps.
  final widthForAll = actionCount * itemExtent + (actionCount - 1) * spacing;
  if (widthForAll <= availableWidth) return actionCount;

  // Otherwise every shown item is followed by a gap, and the overflow button
  // closes the row with its own reservation. Its extent is a separate
  // constant: it belongs to the popup menu button, not to an action, and the
  // two have diverged before.
  final perItem = itemExtent + spacing;
  final fitting = ((availableWidth - menuExtent) / perItem).floor();
  return fitting.clamp(0, actionCount - 1);
}

/// A row of icon actions that moves what does not fit into an overflow menu.
///
/// A toolbar that simply scrolls its actions out of sight looks like the
/// actions are gone: there is nothing to indicate more exists, and no way to
/// reach it without discovering the scroll. The overflow button is the usual
/// answer, and it also lets the hidden actions carry their name, which an icon
/// squeezed into a narrow bar cannot.
class OverflowActionBar extends StatelessWidget {
  const OverflowActionBar({super.key, required this.actions});

  /// Layout width of one [BaseIconButton] at [ButtonSize.small]: the 48 dp
  /// tap target the button pads itself out to, not its 32 dp visual
  /// container. The arithmetic computes how many actions fit in a row, so
  /// it must follow the box the row actually lays out.
  static const double itemExtent = 48;

  /// Width of the overflow button. A [PopupMenuButton] carries its own tap
  /// target and needs its own reservation: it happens to equal [itemExtent]
  /// today, but the two describe different widgets and have diverged
  /// before. Pinned by
  /// `test/shared/widgets/overflow_action_bar_extent_test.dart`.
  static const double menuExtent = 48;

  /// The distance between two actions, and the same number the fitting
  /// arithmetic above budgets for.
  ///
  /// It stays a length rather than becoming a [Proximity] rung, and that is
  /// the point: the two `SizedBox`es below and `visibleActionCount` are ONE
  /// statement, and a rung would let the drawn gap and the budgeted gap
  /// disagree the moment a skin answers the rung with anything but this
  /// number - the bar would then overflow the width it just proved it fits
  /// in. The whole arithmetic belongs in the skin and moves there with this
  /// bar (SKIN-CONTRACT.md §1); until it does, the gap follows the budget.
  static const double spacing = AppTheme.paddingS;

  final List<ToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = visibleActionCount(
          availableWidth: constraints.maxWidth,
          actionCount: actions.length,
        );
        final hidden = actions.skip(visible).toList();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visible; index++) ...[
              if (index > 0) const SizedBox(width: spacing),
              // Loose, and that is the whole point: the count above was
              // computed from [itemExtent], a number this file knows only
              // because the Material icon button happens to lay out at 48 dp.
              // A design language whose mark-only control is wider - the
              // blueprint draws `[trash]` as words, which is exactly what it
              // is for - would make that arithmetic wrong and the row would
              // overflow, which is an exception rather than a layout. A loose
              // flex fit hands each action at most its share and lets it
              // shrink instead, and under Material it changes nothing at all:
              // `visibleActionCount` only ever returns a count whose shares
              // are already >= [itemExtent], so every button still renders at
              // its natural width. The measured arithmetic itself belongs in
              // the skin and moves there with this bar (SKIN-CONTRACT.md §1).
              Flexible(
                child: BaseIconButton(
                  icon: actions[index].icon,
                  tooltip: actions[index].tooltip,
                  onPressed: actions[index].onPressed,
                  size: ButtonSize.small,
                  variant: actions[index].variant,
                ),
              ),
            ],
            if (hidden.isNotEmpty) ...[
              if (visible > 0) const SizedBox(width: spacing),
              // Loose for the same reason the actions are, and the blueprint
              // proved the need rather than the argument doing it: the anchor
              // reserves [menuExtent], another number this file knows only
              // because Material's popup button happens to lay out at 48 dp,
              // and under a language that draws the mark as words the row
              // overflowed by 43 px the moment the anchor stopped being a
              // fixed Phosphor glyph. Under Material nothing moves — the
              // count `visibleActionCount` returns guarantees every share is
              // already >= 48 — and the arithmetic itself still belongs in
              // the skin (SKIN-CONTRACT.md §1).
              Flexible(
                child: BasePopupMenuButton<int>(
                  // The anchor names its meaning like every action beside it.
                  // Left as a raw Phosphor glyph it would have been the one
                  // mark in this bar a Fluent or macOS skin could not answer:
                  // every action drawn in the host language with a Phosphor
                  // "more" mark sitting among them. `ControlScale.normal` is
                  // this skin's 20 dp, which is the size that stood here.
                  icon: const BaseIcon(IconRole.dotsThreeVertical),
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  itemBuilder: (context) => [
                    for (var index = 0; index < hidden.length; index++)
                      PopupMenuItem<int>(
                        value: index,
                        // A disabled entry keeps its tooltip's reason visible
                        // rather than vanishing from the menu.
                        enabled: hidden[index].onPressed != null,
                        child: Tooltip(
                          message: hidden[index].tooltip,
                          child: MenuItemContent(
                            icon: hidden[index].icon,
                            label: hidden[index].label,
                            scale: ControlScale.normal,
                          ),
                        ),
                      ),
                  ],
                  onSelected: (index) => hidden[index].onPressed?.call(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
