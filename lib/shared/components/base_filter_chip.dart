import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Material 3 chip shape shared by every chip in the app: the 8 dp corner
/// the token database gives all three chip classes (Flutter 3.44.4
/// packages/flutter/lib/src/material/chip.dart:2495), which is also the app's
/// control corner for buttons (BTN-001) and the `chipRadius` the theme
/// configures in lib/shared/theme/app_theme.dart:41.
final RoundedRectangleBorder _chipShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppTheme.radiusM),
);

/// The Material 3 chip icon size (Flutter 3.44.4
/// packages/flutter/lib/src/material/chip.dart:2540, `iconTheme.size`).
const double _chipIconSize = 18.0;

/// The leading glyph of a chip. Its color is left to the chip's own icon
/// theme, so selected and unselected resolve exactly as M3 specifies.
Widget? _chipAvatar(IconData? icon) {
  return icon == null ? null : Icon(icon, size: _chipIconSize);
}

/// The label of a chip, as a plain [Text].
///
/// A chip owns its label typography: it wraps the label in a `DefaultTextStyle`
/// built from the resolved chip label style (chip.dart:1445-1451), which is
/// labelLarge in the role the chip's state calls for — `onSecondaryContainer`
/// while selected, `onSurfaceVariant` otherwise (filter_chip.dart:331-337).
/// Wrapping the text in one of the app's `Base*Label` components would replace
/// that with a fixed role and a fixed color and silently drop the per-state
/// pairing, which is the one thing a chip label must not lose.
Widget _chipLabel(String text) => Text(text);

/// Standardized filter chip component for consistent filtering UI across the app.
///
/// Provides a unified design for filter controls with proper theming and accessibility.
///
/// Geometry, typography, state layers and the selection treatment are asserted
/// against the SDK's own `FilterChip` by
/// test/conformance/components/base_filter_chip_conformance_test.dart;
/// the two deliberate divergences — a selected outline that turns `secondary`
/// instead of transparent, and no checkmark — are registered as CHIP-001 and
/// CHIP-002 in docs/deviation_register.yaml.
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
    final colorScheme = Theme.of(context).colorScheme;

    // Build label with optional count
    final String displayLabel = showCount && count != null
        ? '$label ($count)'
        : label;

    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      label: _chipLabel(displayLabel),
      avatar: _chipAvatar(icon),
      // A selected chip is marked by its container and by an outline that
      // turns `secondary`, rather than by the M3 checkmark (CHIP-001,
      // CHIP-002). The outline keeps its 1 dp width so selecting a chip costs
      // no width at all and a filter bar never reflows on a toggle.
      // Everything else — container colors, the unselected outline, padding,
      // label padding, density and the padded tap target — is left to the
      // Material 3 defaults.
      side: selected ? BorderSide(color: colorScheme.secondary) : null,
      shape: _chipShape,
      showCheckmark: false,
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
    final colorScheme = Theme.of(context).colorScheme;

    // ChoiceChip, not FilterChip: single-select is what M3 calls a choice
    // chip, and a skin that maps our components onto another design language
    // has to be told which of the two this is. The `avoid_choice_chip` rule
    // points every call site at this component, which is the one place the
    // wrapped widget is allowed to appear.
    // ignore: avoid_choice_chip
    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      label: _chipLabel(label),
      avatar: _chipAvatar(icon),
      // Same selection treatment as BaseFilterChip: container and outline
      // instead of the M3 checkmark (CHIP-003).
      side: selected ? BorderSide(color: colorScheme.secondary) : null,
      shape: _chipShape,
      showCheckmark: false,
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
    return ActionChip(
      onPressed: onPressed,
      label: _chipLabel(label),
      avatar: _chipAvatar(icon),
      shape: _chipShape,
    );
  }
}
