// FROZEN COPY - do not "improve".
//
//   source:  lib/shared/components/base_filter_chip.dart
//   sha:     19b162315ff8f75b93824b69ce712f15d90104ad
//   copied:  2026-08-06
//
// Permitted edits, and the complete list of them:
//   1. imports retargeted to `../app_stubs.dart`;
//   2. classes renamed BaseFilterChip -> FrozenBaseFilterChip and
//      BaseChoiceChip -> FrozenBaseChoiceChip (pure renames);
//   3. exactly ONE dispatch line in each build(), marked `SKIN DISPATCH`;
//   4. long-form doc comments condensed; every `final` is verbatim.
//
// ADDITION (not an edit to a frozen body, and recorded as a finding):
// [FrozenChoiceChipGroup] at the bottom of this file does not exist in the
// source. It exists because the widget-level seam CANNOT express what
// Cupertino and Fluent do with single-choice chips: the HIG answer to a row of
// choice chips is ONE segmented control, and Fluent's is one ComboBox or one
// radio group. A per-widget skin therefore has nothing to return, and the only
// way to measure the question at all is to introduce the group as its own
// unit. Whether that unit should exist is the deliverable, not a decision the
// spike is entitled to make for #249.
//
// ignore_for_file: avoid_filter_chip, avoid_action_chip

import 'package:flutter/material.dart';

import '../app_stubs.dart';
import '../skin.dart';

/// Standardized filter chip component for consistent filtering UI.
class FrozenBaseFilterChip extends StatelessWidget {
  const FrozenBaseFilterChip({
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

  /// Optional count to display
  final int? count;

  /// Whether to show the count in the label
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.filterChip(this); // SKIN DISPATCH
    // dart format on

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
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

/// Choice chip for single-selection scenarios (radio button style)
class FrozenBaseChoiceChip extends StatelessWidget {
  const FrozenBaseChoiceChip({
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
    // NOTE: no dispatch line. A skin has nothing to return here - see the
    // ADDITION note at the top of this file. This absence is the measurement.
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
        color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
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

/// One option of a single-choice group.
class ChoiceOption {
  const ChoiceOption({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// The single-choice PATTERN as a skinnable unit.
///
/// It is what today's call sites express as a `Wrap` of [FrozenBaseChoiceChip]s
/// - the same information, regrouped so that a skin can answer with ONE widget
/// per language instead of one widget per chip. It is the spike's proposal to
/// #249, and the only component under test whose fix is pattern-level rather
/// than parameter-level.
class FrozenChoiceChipGroup extends StatelessWidget {
  const FrozenChoiceChipGroup({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ChoiceOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.choiceChipGroup(this); // SKIN DISPATCH
    // dart format on

    // Material's own answer to the pattern is SegmentedButton, which is what
    // the current Wrap-of-chips is standing in for.
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        for (int i = 0; i < options.length; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(options[i].label),
            icon: options[i].icon == null ? null : Icon(options[i].icon),
          ),
      ],
      selected: <int>{selectedIndex},
      onSelectionChanged: (Set<int> selection) => onSelected(selection.first),
      showSelectedIcon: false,
    );
  }
}
