import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    this.showLabel = true,
  });

  /// Whether all items are currently selected
  final bool isAllSelected;

  /// Callback when button is pressed (should toggle selection state)
  final VoidCallback onPressed;

  /// Whether to show the label text (defaults to true)
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseButton(
      onPressed: onPressed,
      leadingIcon: isAllSelected
          ? PhosphorIconsRegular.checkSquare
          : PhosphorIconsRegular.square,
      label: showLabel
          ? (isAllSelected ? l10n.deselectAll : l10n.selectAll)
          : '',
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
      icon: isAllSelected
          ? PhosphorIconsRegular.checkSquare
          : PhosphorIconsRegular.square,
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
      icon: PhosphorIconsRegular.checkSquare,
      variant: BadgeVariant.primary,
      size: BadgeSize.medium,
    );
  }
}
