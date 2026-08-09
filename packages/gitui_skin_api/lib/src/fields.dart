import 'package:flutter/widgets.dart';

import 'content_port.dart';
import 'skin.dart';
import 'specs/control_specs.dart';
import 'specs/field_spec.dart';

/// The application's ONLY text-entry API.
///
/// The same shape as the overlay seam, for the same reason. The pre-P0 gate
/// measured that `macos_ui` contains no `FormField` anywhere and that
/// `validate()` over an empty required field returns **true** - and this
/// repository has already shipped that exact defect once, where a dialog's
/// `validate()` found no fields and waved invalid input through. So form
/// registration is not left to each skin to remember: every field goes through
/// here, and [SkinFormFieldHost] registers it once, in one place.
///
/// `FormField` comes from `package:flutter/widgets.dart`, so hosting it costs
/// the contract nothing: the import ban that keeps every Material-named type
/// unnameable here survives intact.
abstract final class Fields {
  /// Asks the user to type something.
  ///
  /// The returned field is registered with the enclosing `Form`, so
  /// `validate()` runs the spec's validator, shows its message on the field
  /// and returns false while the input is unacceptable - under every skin,
  /// including one whose canonical text control knows nothing about forms.
  static Widget text(
    BuildContext context,
    FieldSpec spec, {
    FieldHandles handles = const FieldHandles(),
  }) => SkinScope.render(
    context,
    (Skin skin, BuildContext c) => SkinFormFieldHost(
      spec: spec,
      handles: handles,
      builder: (BuildContext inner, FieldSpec hosted, FieldHandles h) =>
          skin.controls.textField(inner, hosted, h),
    ),
  );

  /// Asks the user to name a moment.
  ///
  /// Not hosted in a `FormField`, and the reason is a measurement rather than
  /// an oversight: no date field in this application carries a validator, and
  /// the one host is typed `FormField<String>` because a date is not a string.
  /// A second host for a second value type would be two mechanisms for one
  /// job. If a date ever needs validating, the honest change is to give
  /// `DateFieldSpec` a validator and widen the ONE host, never to add another.
  static Widget date(
    BuildContext context,
    DateFieldSpec spec, {
    FieldHandles handles = const FieldHandles(),
  }) => SkinScope.render(
    context,
    (Skin skin, BuildContext c) => skin.controls.dateField(c, spec, handles),
  );

  /// Asks the user to narrow a closed list down to one item. Unhosted, for
  /// the same reason as [date], made concrete: a suggest value is a `T`, not
  /// a string, so hosting it would mean a second `FormField` mechanism beside
  /// the one host - and no live suggest field can fail validation today, both
  /// callers arriving with a non-nullable value already chosen. Validation is
  /// this seam's question, never a design language's, so `SuggestFieldSpec`
  /// deliberately carries no validator; when a consumer that can actually
  /// fail exists, the honest change is [date]'s - widen the ONE host - and
  /// that decision is recorded here so it is made then, not defaulted now.
  static Widget suggest<T>(
    BuildContext context,
    SuggestFieldSpec<T> spec, {
    FieldHandles handles = const FieldHandles(),
  }) => SkinScope.render(
    context,
    (Skin skin, BuildContext c) =>
        skin.controls.suggestField<T>(c, spec, handles),
  );
}
