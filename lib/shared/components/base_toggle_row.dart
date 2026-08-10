import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The application's way of stating a fact the user can flip.
///
/// **This is a façade** (#249, §2.11): the body is one delegation to
/// `controls.toggleRow`, and everything a Material `CheckboxListTile` or
/// `SwitchListTile` used to draw here — the control itself, which side of the
/// row it sits on, the row's height and inset, the state layer, the dense
/// treatment, and what a disabled row looks like — is the skin's.
///
/// **The one decision that stays with the caller is [kind]**, and it is not a
/// styling choice. `ToggleKind.check` says "this is selected, as part of a set
/// the user confirms afterwards"; `ToggleKind.switching` says "this is on, and
/// it took effect the moment it changed". A file marked for staging is the
/// first; a preference in Settings is the second. The application knows which
/// of those two things it means and no design language can work it out — but
/// each language draws them very differently, and macOS in particular does not
/// offer a checkbox and a switch as interchangeable ornaments.
///
/// The 45 `CheckboxListTile` / `SwitchListTile` / `RadioListTile` constructions
/// this replaces were the largest single reason `lib/` still imported Flutter's
/// Material library (#443), which is a stricter statement of the same rule
/// #414 measures: a token read is one way to name Material, and reaching for
/// its widgets directly is another.
class BaseToggleRow extends StatelessWidget {
  /// The fact, in words.
  final String label;

  /// Whether it holds — or null for the mixed state, which a tri-state
  /// selection uses to say "some of these, not all".
  final bool? value;

  /// How to tell the application the user flipped it. Null disables the row,
  /// which is how the contract says "present, but not yours to change now"
  /// rather than hiding it.
  final ValueChanged<bool?>? onChanged;

  /// Whether this is a selection to be confirmed or a setting that is already
  /// in force. See the class comment: this is meaning, not appearance.
  final ToggleKind kind;

  /// What flipping it will actually do, where the label alone is not enough.
  final String? description;

  /// A mark at the head of the row.
  final IconRole? leading;

  /// Whether it may be flipped right now. Distinct from a null [onChanged]:
  /// this says the row is temporarily unavailable, that one says it was never
  /// interactive.
  final bool enabled;

  const BaseToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.kind = ToggleKind.check,
    this.description,
    this.leading,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.controls.toggleRow(
          inner,
          ToggleRowSpec(
            label: label,
            value: value,
            onChanged: onChanged,
            kind: kind,
            description: description,
            leading: leading,
            enabled: enabled,
          ),
        );
      });
}
