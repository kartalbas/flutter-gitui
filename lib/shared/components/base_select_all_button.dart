import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';
import 'base_badge.dart';
import 'base_button.dart';

/// Standardized "Select All / Deselect All" button for consistent selection UI.
///
/// Automatically detects selection state and displays appropriate icon/label.
/// Uses theme's color scheme for consistent styling across the app.
///
/// Example usage:
/// ```dart
/// BaseSelectAllButton(
///   isAllSelected: selectedItems.length == totalItems.length,
///   onPressed: () {
///     if (selectedItems.length == totalItems.length) {
///       clearSelection();
///     } else {
///       selectAll();
///     }
///   },
/// )
/// ```
class BaseSelectAllButton extends StatelessWidget {
  const BaseSelectAllButton({
    super.key,
    required this.isAllSelected,
    required this.onPressed,
  });

  /// Whether all items are currently selected
  final bool isAllSelected;

  /// Callback when button is pressed (should toggle selection state)
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseButton(
      onPressed: onPressed,
      // Two PICTURE roles switched by state, which is the shape the contract
      // is trying to remove: the application has pre-chosen Phosphor's
      // checkbox metaphor, so a macOS skin cannot answer "select all" with
      // its own idiom.
      //
      // It cannot be collapsed onto one role plus a state today, and the
      // reason is worth stating precisely, because the obvious fix does not
      // work: the mechanism that recovers a state on the skin's side —
      // `IconButtonSpec.selected` answered by `MaterialGlyphs.filledOf` —
      // switches the FONT FAMILY at one codepoint, so it can only make the
      // same mark solid. `square` and `checkSquare` are different codepoints,
      // a ticked box and an empty one, so routing them through it would draw
      // an empty box where a ticked box is drawn today. The real fix is a
      // `checked` state on the button's spec — the shape `MenuCheckable` and
      // `TreeNodeSpec` already have — with the PAIR of marks chosen by the
      // skin. That is a contract member, not a call-site edit, so it belongs
      // to the phase that migrates the specs and not to the icon conversion.
      leadingIcon: isAllSelected ? IconRole.checkSquare : IconRole.square,
      label: isAllSelected ? l10n.deselectAll : l10n.selectAll,
      variant: ButtonVariant.tertiary,
      size: ButtonSize.small,
    );
  }
}

/// Compact icon-only version of BaseSelectAllButton for tight spaces
///
/// Example usage:
/// ```dart
/// BaseSelectAllIconButton(
///   isAllSelected: selectedItems.length == totalItems.length,
///   onPressed: toggleSelectAll,
/// )
/// ```
class BaseSelectAllIconButton extends StatelessWidget {
  const BaseSelectAllIconButton({
    super.key,
    required this.isAllSelected,
    required this.onPressed,
  });

  /// Whether all items are currently selected
  final bool isAllSelected;

  /// Callback when button is pressed (should toggle selection state)
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseIconButton(
      onPressed: onPressed,
      // The same two picture roles as [BaseSelectAllButton], for the same
      // reason and with the same fix pending; see the comment there.
      icon: isAllSelected ? IconRole.checkSquare : IconRole.square,
      tooltip: isAllSelected ? l10n.deselectAll : l10n.selectAll,
      size: ButtonSize.small,
    );
  }
}

/// Selection count badge to show number of selected items
///
/// Example usage:
/// ```dart
/// if (selectedItems.isNotEmpty)
///   BaseSelectionCountBadge(count: selectedItems.length)
/// ```
class BaseSelectionCountBadge extends StatelessWidget {
  const BaseSelectionCountBadge({super.key, required this.count});

  /// Number of selected items
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseBadge(
      label: l10n.selectedCount(count),
      icon: IconRole.checkSquare,
      variant: BadgeVariant.primary,
      size: BadgeSize.medium,
    );
  }
}
