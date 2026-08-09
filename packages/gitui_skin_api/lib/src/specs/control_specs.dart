import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../vocabulary.dart';

/// What a button offers to do.
///
/// Note the split of a seven-value `ButtonVariant` into [Emphasis] and [Tone]:
/// `dangerSecondary` was a Material compound, while "quiet, and destructive"
/// is a meaning three languages can each answer their own way. The spike
/// classified `variant` as ADAPTED in both non-Material languages for exactly
/// this reason - the compound had to be decomposed at the skin boundary.
@immutable
final class ButtonSpec {
  /// Declares one button.
  const ButtonSpec({
    required this.label,
    required this.onPressed,
    this.emphasis = Emphasis.primary,
    this.tone = Tone.accent,
    this.scale = ControlScale.normal,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.fillWidth = false,
    this.tooltip,
  });

  /// The button's words, and its accessible name.
  final String label;

  /// What it does. Null disables it.
  final VoidCallback? onPressed;

  /// How loudly it asks to be used.
  final Emphasis emphasis;

  /// What using it means.
  final Tone tone;

  /// How much room it is entitled to.
  final ControlScale scale;

  /// A mark before the words.
  final IconRole? leading;

  /// A mark after the words - a chevron, an external-link mark.
  final IconRole? trailing;

  /// Whether it is running, so the skin can show progress in its place.
  final bool isLoading;

  /// Whether it should take the whole width it is offered. Structure rather
  /// than appearance: it is what the layout around it means, not what the
  /// button looks like.
  final bool fillWidth;

  /// A longer explanation, and the REASON when the button is unavailable.
  final String? tooltip;
}

/// What a mark-only control offers to do.
@immutable
final class IconButtonSpec {
  /// Declares one icon button.
  const IconButtonSpec({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasis = Emphasis.quiet,
    this.tone = Tone.neutral,
    this.scale = ControlScale.normal,
    this.selected,
    this.badgeCount,
  });

  /// The mark.
  final IconRole icon;

  /// What it does. Required, not optional: a mark-only control has to name
  /// itself, and this repository's rules make that non-negotiable. It doubles
  /// as the accessible name.
  final String tooltip;

  /// What it does. Null disables it.
  final VoidCallback? onPressed;

  /// How loudly it asks to be used.
  final Emphasis emphasis;

  /// What using it means.
  final Tone tone;

  /// How much room it is entitled to.
  final ControlScale scale;

  /// Whether it is currently on, or null when it is not a toggle at all. The
  /// three states are distinct: a toggle that is off is not the same control
  /// as one that has no state to report.
  final bool? selected;

  /// A count riding on the mark, or null.
  final int? badgeCount;
}

/// A fact the user can flip.
///
/// [value] is `bool?` and not `bool`, because the mixed state is live in this
/// application today: a folder whose children are only partly selected. The
/// three languages disagree about it - Material asserts `tristate || value !=
/// null`, Fluent's `checked` is nullable, and macOS can DISPLAY the mixed
/// state but its `onChanged` can never emit one, which is a registered loss.
@immutable
final class ToggleSpec {
  /// Declares one toggle.
  const ToggleSpec({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  /// Whether the fact holds - or null while it holds for only part of what the
  /// control stands for.
  final bool? value;

  /// How to tell the application the user flipped it. Null disables it.
  final ValueChanged<bool?>? onChanged;

  /// What the fact is, for a screen reader only. The VISIBLE label belongs to
  /// `controls.toggleRow`, which is a different member because it is a
  /// different canonical widget in two of the three languages.
  final String? label;

  /// Whether it may be flipped right now.
  final bool enabled;
}

/// A fact the user can flip, with its name beside it.
///
/// Its own member rather than a label on [ToggleSpec] because Material reaches
/// for a different canonical widget (`CheckboxListTile`, `SwitchListTile`) and
/// Fluent for a different constructor (`Checkbox(content:)`), while macOS has
/// no label slot at all and composes the whole row. Measured at 36 sites.
@immutable
final class ToggleRowSpec {
  /// Declares one labelled toggle row.
  const ToggleRowSpec({
    required this.label,
    required this.value,
    required this.onChanged,
    this.kind = ToggleKind.check,
    this.description,
    this.leading,
    this.enabled = true,
  });

  /// The fact, in words.
  final String label;

  /// Whether it holds - or null for the mixed state.
  final bool? value;

  /// How to tell the application the user flipped it. Null disables the row.
  final ValueChanged<bool?>? onChanged;

  /// Which toggle idiom this is: a selection to be confirmed, or a setting
  /// that takes effect at once.
  final ToggleKind kind;

  /// What flipping it will actually do, where the label alone is not enough.
  final String? description;

  /// A mark at the head of the row.
  final IconRole? leading;

  /// Whether it may be flipped right now.
  final bool enabled;
}

/// A number the user picks by position along a range.
@immutable
final class SliderSpec {
  /// Declares one slider.
  const SliderSpec({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueLabel,
    this.onChangeEnd,
    this.enabled = true,
  });

  /// Where the user is now.
  final double value;

  /// The smallest value that means anything here.
  final double min;

  /// The largest.
  final double max;

  /// How to tell the application the user is moving it. Null disables it.
  final ValueChanged<double>? onChanged;

  /// How many steps the range has, or null when it is continuous. A fact
  /// about the VALUE - a clone depth is a whole number of commits - not about
  /// tick marks, which are the skin's answer to it.
  final int? divisions;

  /// The current value in words, where a number alone would not read.
  final String? valueLabel;

  /// How to tell the application the user let go, for the work that should
  /// happen once rather than on every frame.
  final ValueChanged<double>? onChangeEnd;

  /// Whether it may be moved right now.
  final bool enabled;
}

/// A moment the user names.
@immutable
final class DateFieldSpec {
  /// Declares one date field.
  const DateFieldSpec({
    required this.value,
    required this.onChanged,
    required this.label,
    this.first,
    this.last,
    this.hint,
    this.precision = DatePrecision.date,
    this.enabled = true,
  });

  /// The moment named so far, or null while none is.
  final DateTime? value;

  /// How to tell the application the user named another one.
  final ValueChanged<DateTime?> onChanged;

  /// What the moment is for: "Since", "Expires".
  final String label;

  /// The earliest moment that means anything here.
  final DateTime? first;

  /// The latest.
  final DateTime? last;

  /// What to say while nothing is named.
  final String? hint;

  /// How precisely the user is being asked to answer. It exists so that a time
  /// field extends this member rather than adding one.
  final DatePrecision precision;

  /// Whether it may be changed right now.
  final bool enabled;
}

/// One of the things a suggest field can settle on.
@immutable
final class SuggestItem<T> {
  /// Declares one suggestion.
  const SuggestItem({
    required this.value,
    required this.label,
    this.icon,
    this.detail,
  });

  /// What choosing it means.
  final T value;

  /// What it is called, and what the user's typing is matched against.
  final String label;

  /// A mark beside the name.
  final IconRole? icon;

  /// What distinguishes it from a similarly named one: a path, an owner.
  final String? detail;
}

/// A field that narrows a closed list and settles on one of its items.
///
/// A different question from a plain dropdown, and a different canonical
/// widget in all three languages - `DropdownMenu(enableFilter:)`,
/// `AutoSuggestBox<T>`, `MacosSearchField<T>`. A boolean on the dropdown spec
/// that switched which class a skin instantiates would be exactly the compound
/// the contract split when it turned a seven-value `ButtonVariant` into
/// [Emphasis] by [Tone].
@immutable
final class SuggestFieldSpec<T> {
  /// Declares one suggest field.
  const SuggestFieldSpec({
    required this.label,
    required this.value,
    required this.items,
    required this.onSelected,
    this.onQueryChanged,
    this.hint,
    this.leading,
    this.minQueryLength = 0,
    this.emptyLabel,
    this.enabled = true,
  });

  /// What kind of thing is being named.
  final String label;

  /// Which one is named so far, or null.
  final T? value;

  /// Everything it could settle on.
  final List<SuggestItem<T>> items;

  /// How to tell the application the user settled on one.
  final ValueChanged<T> onSelected;

  /// How to tell the application what the user has typed, for a list that is
  /// fetched rather than filtered in memory.
  final ValueChanged<String>? onQueryChanged;

  /// What to say while nothing is typed.
  final String? hint;

  /// A mark at the head of the field, saying what kind of thing is being
  /// narrowed. The same slot [DropdownSpec.leading] and `FieldSpec.leading`
  /// already carry; a suggest field that could not say "this names a branch"
  /// while its siblings could would be a vocabulary hole, not a look.
  final IconRole? leading;

  /// How much the user must type before suggesting is useful. A fact about the
  /// data - a list of ten needs none, a list of ten thousand needs three.
  final int minQueryLength;

  /// What to say when nothing matches.
  final String? emptyLabel;

  /// Whether it may be used right now.
  final bool enabled;
}

/// One of the things a dropdown can settle on.
@immutable
final class DropdownOption<T> {
  /// Declares one option.
  const DropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.detail,
    this.enabled = true,
  });

  /// What choosing it means.
  final T value;

  /// What it is called.
  final String label;

  /// A mark beside the name.
  final IconRole? icon;

  /// What distinguishes it from a similarly named one.
  final String? detail;

  /// Whether it may be chosen right now. A disabled option stays visible, so
  /// the user can see that the thing exists and is merely unavailable.
  final bool enabled;
}

/// A field that settles on one of a short closed list.
@immutable
final class DropdownSpec<T> {
  /// Declares one dropdown.
  const DropdownSpec({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.leading,
    this.enabled = true,
    this.fillWidth = true,
    this.autofocus = false,
    this.focusNode,
  });

  /// What kind of thing is being named.
  final String label;

  /// Which one is named, or null.
  final T? value;

  /// Everything it could settle on.
  ///
  /// Data rather than per-option builders. A builder is a `Widget`-typed seam,
  /// and a `Widget`-typed seam is exactly what lets the wrong design language
  /// through the type system unnoticed.
  final List<DropdownOption<T>> options;

  /// How to tell the application the user settled on one. Null disables it.
  final ValueChanged<T?>? onChanged;

  /// What to say while nothing is named.
  final String? hint;

  /// A mark at the head of the field.
  final IconRole? leading;

  /// Whether it may be used right now.
  final bool enabled;

  /// Whether it should take the whole width it is offered.
  final bool fillWidth;

  /// Whether it should take the keyboard when the surface opens.
  final bool autofocus;

  /// The application's own handle on this control's focus, for the screens
  /// that hand focus between controls themselves. A `FocusNode` is a
  /// behaviour object, not a design value.
  final FocusNode? focusNode;
}

/// One of the mutually exclusive choices a group offers.
@immutable
final class ChoiceOption<T> {
  /// Declares one choice.
  const ChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
    this.enabled = true,
  });

  /// What choosing it means.
  final T value;

  /// The option's words, and its accessible name.
  final String label;

  /// A mark beside the words.
  final IconRole? icon;

  /// What the option actually selects, where the label is a symbol rather than
  /// a word. Without it, the search-mode switch that labels its segments `Aa`,
  /// `*` and `.*` is unreadable - and this repository's rules make a tooltip on
  /// a symbol-only control non-negotiable.
  final String? tooltip;

  /// Whether it may be chosen right now.
  final bool enabled;
}

/// Pick exactly one of a few.
///
/// The GROUP is the unit, not the choice. A single choice chip is a Material
/// idea with no counterpart elsewhere: macOS answers "pick one of a few" with
/// one segmented control and Fluent with one radio group, and neither has a
/// widget for "one segment on its own" that a caller could place in a layout
/// of its own making.
@immutable
final class ChoiceGroupSpec<T> {
  /// Declares one choice group.
  const ChoiceGroupSpec({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.label,
    this.scale = ControlScale.normal,
  });

  /// The choices, in the order they are offered.
  final List<ChoiceOption<T>> options;

  /// Which one is chosen.
  ///
  /// Nullable, and a value matching none of the options is equally legal: both
  /// mean "nothing has been chosen yet", which is a real state for a form that
  /// starts blank.
  final T? selected;

  /// How to tell the application the user chose one. It fires only on a
  /// choice, never on a de-selection: "exactly one" is what the group
  /// promises, and there is no second gesture that could restore it.
  final ValueChanged<T> onSelected;

  /// What the group is choosing, for a screen reader.
  final String? label;

  /// How much room the group is entitled to.
  final ControlScale scale;
}

/// One condition the user can switch on to narrow what is shown.
///
/// Per item rather than per set, because all three languages have a per-item
/// toggle for it - and because the set is not closed: filters are added and
/// removed as the data allows.
@immutable
final class FilterToggleSpec {
  /// Declares one filter toggle.
  const FilterToggleSpec({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.count,
    this.enabled = true,
  });

  /// What the condition is, in words.
  final String label;

  /// Whether it is on.
  final bool selected;

  /// How to tell the application the user switched it.
  final ValueChanged<bool> onSelected;

  /// A mark beside the words.
  final IconRole? icon;

  /// How many things match this condition, or null when that is not worth
  /// saying. There is no separate "show the count" flag: null already means
  /// "do not say".
  final int? count;

  /// Whether it may be switched right now.
  final bool enabled;
}

/// Pick one of the skin's own generated colours.
///
/// The only way a user can choose a workspace or project colour once
/// `Tone.series` owns both the palette AND its length. The application indexes;
/// it cannot enumerate, and after this member exists there is no legal way for
/// it to find out how many swatches there are. Deliberately NOT a free colour
/// picker - `MacosColorWell` and Fluent's `ColorPicker` both exist, and both
/// would move a `Color` across the seam.
@immutable
final class SeriesPickerSpec {
  /// Declares one series picker.
  const SeriesPickerSpec({
    required this.selectedIndex,
    required this.onSelected,
    this.label,
  });

  /// Which member of the series is chosen, or null while none is.
  final int? selectedIndex;

  /// How to tell the application the user chose one.
  final ValueChanged<int> onSelected;

  /// What the colour will stand for, for a screen reader.
  final String? label;
}
