import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'base_menu_item.dart';

/// Standardized filter chip component for consistent filtering UI across the app.
///
/// Provides a unified design for filter controls with proper theming and accessibility.
///
/// Example usage:
/// ```dart
/// BaseFilterChip(
///   label: 'Clean Only',
///   selected: isCleanOnlyFiltered,
///   icon: PhosphorIconsRegular.checkCircle,
///   onSelected: (selected) => setState(() => isCleanOnlyFiltered = selected),
/// )
/// ```
class BaseFilterChip extends StatelessWidget {
  const BaseFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.count,
    this.showCount = false,
  });

  /// Label text for the filter chip
  final String label;

  /// Whether this filter is currently selected/active
  final bool selected;

  /// Callback when selection state changes
  final ValueChanged<bool> onSelected;

  /// Optional leading icon
  final IconData? icon;

  /// Optional count to display (e.g., number of items matching this filter)
  final int? count;

  /// Whether to show the count in the label
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build label with optional count
    final String displayLabel = showCount && count != null
        ? '$label ($count)'
        : label;

    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      label: MenuItemLabel(
        displayLabel,
        color: selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16, // Standardized icon size for filter chips
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            )
          : null,
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      side: BorderSide(
        color: selected
            ? colorScheme.secondary
            : colorScheme.outlineVariant,
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: 2,
      ),
      labelPadding: icon != null
          ? const EdgeInsets.only(right: AppTheme.paddingS)
          : const EdgeInsets.symmetric(horizontal: AppTheme.paddingS),
      showCheckmark: false, // We use color/border to indicate selection
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Choice chip for single-selection scenarios (radio button style)
///
/// Example usage:
/// ```dart
/// BaseChoiceChip(
///   label: 'Feature',
///   selected: selectedPrefix == BranchPrefix.feature,
///   onSelected: (selected) {
///     if (selected) setState(() => selectedPrefix = BranchPrefix.feature);
///   },
/// )
/// ```
class BaseChoiceChip extends StatelessWidget {
  const BaseChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  /// Label text for the choice chip
  final String label;

  /// Whether this choice is currently selected
  final bool selected;

  /// Callback when selection state changes
  final ValueChanged<bool> onSelected;

  /// Optional leading icon
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      label: MenuItemLabel(
        label,
        color: selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            )
          : null,
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      side: BorderSide(
        color: selected
            ? colorScheme.secondary
            : colorScheme.outlineVariant,
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: 2,
      ),
      labelPadding: icon != null
          ? const EdgeInsets.only(right: AppTheme.paddingS)
          : const EdgeInsets.symmetric(horizontal: AppTheme.paddingS),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Action chip for quick filter actions (doesn't toggle, triggers action)
///
/// Example usage:
/// ```dart
/// BaseActionChip(
///   label: 'Today',
///   icon: PhosphorIconsRegular.calendar,
///   onPressed: () => applyTodayFilter(),
/// )
/// ```
class BaseActionChip extends StatelessWidget {
  const BaseActionChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Label text for the action chip
  final String label;

  /// Callback when chip is pressed
  final VoidCallback onPressed;

  /// Optional leading icon
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ActionChip(
      onPressed: onPressed,
      label: MenuItemLabel(
        label,
        color: colorScheme.onSurfaceVariant,
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16, // Standardized icon size
              color: colorScheme.onSurfaceVariant,
            )
          : null,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: colorScheme.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: 2,
      ),
      labelPadding: icon != null
          ? const EdgeInsets.only(right: AppTheme.paddingS)
          : const EdgeInsets.symmetric(horizontal: AppTheme.paddingS),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
