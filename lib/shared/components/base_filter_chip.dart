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

/// One of the mutually exclusive choices a [BaseChoiceGroup] offers.
///
/// Data, not a widget, because the group is what gets rendered and each design
/// language renders it out of its own parts: Material 3 builds a row of choice
/// chips (or a `SegmentedButton`), Apple's HIG a
/// `CupertinoSlidingSegmentedControl`, Fluent 2 a `RadioGroup` of radio
/// buttons. None of those can be assembled out of ready-made per-option
/// widgets belonging to a different language.
@immutable
class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label, this.icon});

  /// What choosing this option means, handed back to
  /// [BaseChoiceGroup.onSelected] and compared against
  /// [BaseChoiceGroup.selected].
  final T value;

  /// The option's text, and its accessible name.
  final String label;

  /// An optional leading glyph. [IconData] is language-neutral — Flutter's
  /// Material, Cupertino and Fluent libraries all take it.
  final IconData? icon;
}

/// A group of mutually exclusive choices: pick exactly one.
///
/// **The group is the component, not the individual choice.** That is a
/// deliberate correction of the earlier `BaseChoiceChip`, and the one
/// pattern-level change the skin viability spike found. A single choice chip
/// is a Material idea with no counterpart anywhere else: the iOS HIG answers
/// "pick one of a few" with one segmented control and Fluent 2 with one radio
/// group, and neither has a widget for "one segment on its own" that a caller
/// could place in a `Wrap` of its own making. A component that renders one
/// chip therefore has nothing to hand another design language, while a
/// component that renders the whole group has the complete question —
/// the options, and which of them is chosen — and can answer it in any
/// language.
///
/// Material 3 renders the group as a row of `ChoiceChip`s, which is the
/// rendering the app already shipped and the one the conformance suite
/// measures; the chips are an implementation detail of this component and no
/// longer constructible from outside it.
///
/// Example usage:
/// ```dart
/// BaseChoiceGroup<BranchPrefix>(
///   options: [
///     ChoiceOption(value: BranchPrefix.feature, label: 'feature'),
///     ChoiceOption(value: BranchPrefix.hotfix, label: 'hotfix'),
///   ],
///   selected: _selectedPrefix,
///   onSelected: (prefix) => setState(() => _selectedPrefix = prefix),
/// )
/// ```
class BaseChoiceGroup<T> extends StatelessWidget {
  const BaseChoiceGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// The choices on offer, in the order they are shown.
  final List<ChoiceOption<T>> options;

  /// The value that is currently chosen.
  ///
  /// Nullable, and a value matching none of the [options] is equally legal:
  /// both mean "nothing has been chosen yet", which is a real state for a form
  /// that starts blank. The group then renders every option unselected rather
  /// than inventing a default the caller did not ask for.
  final T? selected;

  /// Called with the value of the option the user chose.
  ///
  /// It fires only on a choice, never on a de-selection: re-tapping the chosen
  /// option in a single-choice group is a no-op, because "exactly one" is what
  /// the group promises and there is no second gesture that could restore it.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.paddingS,
      runSpacing: AppTheme.paddingS,
      children: <Widget>[
        for (final ChoiceOption<T> option in options)
          _ChoiceChip(
            label: option.label,
            icon: option.icon,
            selected: option.value == selected,
            onSelected: () => onSelected(option.value),
          ),
      ],
    );
  }
}

/// Material 3's rendering of one option of a [BaseChoiceGroup].
///
/// Private on purpose: a lone choice chip is exactly what R3 of the skin spike
/// removed from the public surface, so the only way to get one is to ask for a
/// group. The conformance suite still measures it under the token prefix
/// `BaseChoiceChip.*`, because that is the name the checked-in token manifest
/// and the CHIP-003 register entry use for this element.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ChoiceChip, not FilterChip: single-select is what M3 calls a choice
    // chip, and a skin that maps our components onto another design language
    // has to be told which of the two this is. The `avoid_choice_chip` rule
    // points every call site at BaseChoiceGroup, which reaches the wrapped
    // widget only through here — the one place it is allowed to appear.
    // ignore: avoid_choice_chip
    return ChoiceChip(
      selected: selected,
      // A chip reports the state it would flip to, so re-tapping the chosen
      // option arrives here as `false`. A single-choice group has no "none"
      // state to flip to, so that report is dropped rather than passed on.
      onSelected: (bool isNowSelected) {
        if (isNowSelected) onSelected();
      },
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
