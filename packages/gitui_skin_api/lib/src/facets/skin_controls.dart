import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../specs/control_specs.dart';
import '../specs/field_spec.dart';
import '../vocabulary.dart';

/// Things you operate.
///
/// Fifteen members. `actionBar` is deliberately absent: the arity of a toolbar
/// is the BAR, because two of the three languages own overflow there, and both
/// frames already carry one - so a third way to ask for a toolbar would have
/// been a third way to ask for the same thing.
abstract interface class SkinControls {
  /// **What can the user do here, in words?**
  Widget button(BuildContext context, ButtonSpec spec);

  /// **What can the user do here, as a mark?**
  ///
  /// A separate member rather than a button with no label, because a mark-only
  /// control has its own canonical widget, its own hit target and its own
  /// tooltip obligation in all three languages.
  Widget iconButton(BuildContext context, IconButtonSpec spec);

  /// **What is the application asking the user to type?**
  ///
  /// Called through the package's own field seam, never directly: the seam
  /// wraps whatever this returns in the single `FormField<String>` host, so
  /// that `validate()` keeps guarding under a skin whose canonical text
  /// control does not register with a `Form` at all.
  Widget textField(BuildContext context, FieldSpec spec, FieldHandles handles);

  /// **Which moment is the application asking the user to name?**
  Widget dateField(
    BuildContext context,
    DateFieldSpec spec,
    FieldHandles handles,
  );

  /// **Which item of a closed list is the user narrowing towards?**
  ///
  /// Distinct from [dropdown] because it is a different canonical widget class
  /// in every language, not a flag on the same one.
  Widget suggestField<T>(
    BuildContext context,
    SuggestFieldSpec<T> spec,
    FieldHandles handles,
  );

  /// **Is this fact true?** - as a mark the user sets, with no words of its
  /// own.
  Widget checkbox(BuildContext context, ToggleSpec spec);

  /// **Is this setting on?** - taking effect the moment it changes.
  Widget toggle(BuildContext context, ToggleSpec spec);

  /// **Is this named fact true?**
  ///
  /// The whole row, because Material reaches for a different canonical widget
  /// for it, Fluent for a different constructor, and macOS has no label slot
  /// at all and must compose the row itself.
  Widget toggleRow(BuildContext context, ToggleRowSpec spec);

  /// **Where along this range is the user?**
  Widget slider(BuildContext context, SliderSpec spec);

  /// **Which one of these is it?** - for a list too long to show at once.
  Widget dropdown<T>(BuildContext context, DropdownSpec<T> spec);

  /// **Which one of these few is it?**
  ///
  /// The group and not the choice, because a single choice chip is a Material
  /// idea with no counterpart in the other two languages.
  Widget choiceGroup<T>(BuildContext context, ChoiceGroupSpec<T> spec);

  /// **Is this condition on?** - one of a set of filters the user combines.
  Widget filterToggle(BuildContext context, FilterToggleSpec spec);

  /// **Which of the skin's own colours does this object get?**
  ///
  /// The only member the application cannot work around: once the palette AND
  /// its length belong to the skin, there is no legal way for the application
  /// to know how many swatches to offer.
  Widget seriesPicker(BuildContext context, SeriesPickerSpec spec);

  /// **How far along is this, and how much room may saying so take?**
  ///
  /// A null [fraction] means the end is unknowable, which every language draws
  /// differently and one of them cannot draw at all in its bar form - a
  /// registered loss rather than a hand-painted lookalike.
  Widget progress(
    BuildContext context, {
    double? fraction,
    required ProgressExtent extent,
  });

  /// **What does this thing do, for someone who cannot tell by looking?**
  ///
  /// The message is a plain `String` and the child is a port, so the
  /// explanation is the application's and its presentation is the skin's.
  Widget describedBy(
    BuildContext context, {
    required String message,
    required ContentPort child,
  });
}
