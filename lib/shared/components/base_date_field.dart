import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../generated/app_localizations.dart';

/// The application's way of asking the user to name a moment.
///
/// **This is a façade** (#249, §2.11): the constructor is exactly the one 4
/// call sites already write, and the body is one delegation to
/// `controls.dateField`. Everything the field used to draw itself — the
/// `InputDecorator` around a value, the `MouseRegion` and
/// `FocusableActionDetector` that feed it `isHovering` and `isFocused` rather
/// than an `InkWell` that would paint a second highlight over both, the
/// `ActivateIntent`/`ButtonActivateIntent` pair that makes Enter and Space open
/// the picker, the `yyyy-MM-dd` rendering and the picker itself — moved into
/// the Material skin, verbatim, together with the comments recording why each
/// one is the way it is.
///
/// What stays here is the two things that are the application's and not a
/// design language's: *what* is being asked for ([label], [firstDate],
/// [lastDate]) and *what the field says while nothing is named* — the hint is
/// this application's own translated sentence, so it crosses the contract as a
/// string rather than being invented by the skin.
class BaseDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const BaseDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) => SkinScope.render(context, (
    Skin skin,
    BuildContext inner,
  ) {
    return skin.controls.dateField(
      inner,
      DateFieldSpec(
        value: value,
        onChanged: onChanged,
        label: label,
        first: firstDate,
        last: lastDate,
        hint: AppLocalizations.of(inner)!.selectDate,
      ),
      // No controller and no focus node: this component never offered the
      // caller either, so there is nothing for the application to hold on to
      // and the skin owns the field's whole editing state.
      const FieldHandles(),
    );
  });
}

// `showThemedDatePicker` used to live here and no longer does. The picker the
// user opens is the Material skin's (`material_controls.dart`, reached from
// this field's own `controls.dateField`), and this file kept a second,
// unreachable copy so that `base_date_field_picker_theme_test.dart` had
// something on the application's side to measure. That is exactly the failure
// mode the #400 test exists to prevent, one level up: the guard would have
// stayed green while the function the application actually runs drifted. The
// test now opens this field and inspects the picker it really gets, so the copy
// had nothing left to justify it.
