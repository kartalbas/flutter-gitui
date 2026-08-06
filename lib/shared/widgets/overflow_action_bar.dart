import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../components/base_animated_widgets.dart';
import '../components/base_button.dart';
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

  final IconData icon;

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
              BaseIconButton(
                icon: actions[index].icon,
                tooltip: actions[index].tooltip,
                onPressed: actions[index].onPressed,
                size: ButtonSize.small,
                variant: actions[index].variant,
              ),
            ],
            if (hidden.isNotEmpty) ...[
              if (visible > 0) const SizedBox(width: spacing),
              BasePopupMenuButton<int>(
                icon: const Icon(
                  PhosphorIconsRegular.dotsThreeVertical,
                  size: AppTheme.iconM,
                ),
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
                          iconSize: AppTheme.iconM,
                        ),
                      ),
                    ),
                ],
                onSelected: (index) => hidden[index].onPressed?.call(),
              ),
            ],
          ],
        );
      },
    );
  }
}
