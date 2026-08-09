import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        FieldActionAffordance,
        FieldAffordance,
        FieldClearAffordance,
        FieldHandles,
        FieldPurpose,
        FieldRevealAffordance,
        FieldSpec,
        Fields,
        IconRole;

/// How loudly a text field asserts itself on the surface it sits on.
///
/// The values name the field's *role*, not the class that happens to draw it
/// today. The previous names — `standard`, `outlined`, `filled` — were the
/// Material border classes read out loud (`UnderlineInputBorder`,
/// `OutlineInputBorder`, and `filled: true`), so a design language that has no
/// such classes had nothing to map: Apple's HIG and Fluent 2 each give a text
/// field exactly one appearance, and asking either of them for "the
/// OutlineInputBorder one" is a question with no answer. Asking instead for
/// "the ordinary form field" or "the one that carries the most weight" is a
/// question every design language can answer, even when its answer is that
/// both look alike.
///
/// **There used to be a third rung, `minimal`** — "the field recedes: it marks
/// the writing line and nothing else", which Material drew as an
/// `UnderlineInputBorder`. It is gone, and its removal is the contract
/// arriving rather than a feature being dropped. No screen in `lib/` ever
/// asked for it: its only consumers were the two package test suites that
/// enumerate `TextFieldVariant.values`. `FieldPurpose` carries "only the
/// values for which a language reaches for a different canonical widget",
/// and a receding field is not one of them — macOS and Fluent 2 give a text
/// field one appearance each, so Material's low-emphasis *rendering* was the
/// only thing the rung ever named. Keeping it would have meant this component
/// hand-painting one variant while the other two were drawn behind the seam,
/// which is the half-migration the corner retirement exists to end. The
/// missing word is reported as a contract finding, not invented here.
enum TextFieldVariant {
  /// The ordinary form field, and the default: the input draws a complete
  /// boundary around itself so it reads as one editable unit among labels and
  /// buttons. Material 3 draws it as an outlined box.
  bordered,

  /// The field is the most prominent thing on its surface, because typing in
  /// it *is* the task — a search bar, a command palette, a filter box.
  /// Material 3 draws it as a filled box, which its own guidance calls the
  /// higher-emphasis of the two field types.
  emphasized,
}

/// Base component for all text input patterns in the app.
///
/// **This is a façade** (#249, §2.11), on the same terms as `BaseCard`,
/// `BaseDialog` and `BaseListItem`: the constructor is the one forty-five call
/// sites already write, and the body is one delegation to `controls.textField`
/// through [Fields.text]. Everything the field used to draw and drive itself —
/// the outlined and filled border shapes and the 4 dp corner both repeated
/// five times over, the spelled-out focus, error and focused-error sides of
/// the filled variant, the controller ownership, the Escape-to-clear ladder,
/// the double-click select-all and the in-field affordance — is in the skin
/// already, comment for comment (`material_controls.dart`,
/// `_fieldDecoration` and `_MaterialTextField`). Nothing was re-decided on the
/// way.
///
/// **What the move deletes is every corner this file could state.** A field's
/// corner is not a number the application knows: Material rounds a field at 4,
/// Fluent at 4 and macOS at 6, and all three are right. The five
/// `BorderRadius.circular` calls left with the decoration they belonged to,
/// and there is no rung, word or token replacing them — asking for one would
/// be the same mistake in a neutral costume.
///
/// **What the move changes, and why the member's answer is right:**
///
///  * A **clear** affordance is now stated as a fact about the field ("this
///    one can be emptied") rather than built here, so the language decides
///    whether it appears at all and what it is called;
///    `MacosTextField.clearButtonMode` is the measured case the sealed set
///    exists for. Its tooltip comes from `MaterialLocalizations` instead of
///    this application's `l10n.clear`, which is the same word from the
///    platform's own catalogue.
///  * A **decorative** suffix — a mark with no handler — has no counterpart in
///    the contract's sealed affordance set, because a field's trailing slot is
///    where an ACTION lives. It is stated as an action that cannot be taken
///    (`onPressed: null`), so the mark survives and now reads as inert instead
///    of impersonating a button. Reported as a contract finding.
///
/// Geometry, outline colors per state, typography and the disabled and error
/// treatments are asserted against a real SDK `TextField` by
/// packages/gitui_skin_material/test/conformance/components/base_text_field_conformance_test.dart;
/// the three deliberate divergences are registered as FIELD-001..FIELD-003 in
/// packages/gitui_skin_material/docs/deviation_register.yaml.
///
/// Example usage:
/// ```dart
/// BaseTextField(
///   label: 'Branch name',
///   hintText: 'Enter branch name',
///   prefixIcon: IconRole.gitBranch,
///   showClearButton: true,
///   onChanged: (value) => print(value),
/// )
/// ```
///
/// Password field example:
/// ```dart
/// BaseTextField(
///   label: 'Password',
///   obscureText: true,
///   showPasswordToggle: true,
///   prefixIcon: IconRole.lock,
/// )
/// ```
///
/// Search field example:
/// ```dart
/// BaseTextField(
///   hintText: 'Search repositories...',
///   prefixIcon: IconRole.magnifyingGlass,
///   showClearButton: true,
///   variant: TextFieldVariant.emphasized,
/// )
/// ```
class BaseTextField extends StatelessWidget {
  const BaseTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.suffixTooltip,
    this.variant = TextFieldVariant.bordered,
    this.obscureText = false,
    this.showClearButton = false,
    this.showPasswordToggle = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.enabled = true,
    this.escapeClears = true,
  }) : assert(
         controller == null || initialValue == null,
         'Pass either a controller or an initialValue, not both: the '
         'controller already carries the text the field starts with.',
       );

  /// Text editing controller (optional - the skin creates one if not provided)
  final TextEditingController? controller;

  /// The text the field starts with, for a caller that keeps no controller.
  ///
  /// A dialog that only needs the final text does not want to own a
  /// controller: the controller has to outlive the route's exit transition,
  /// and disposing it when `showDialog`'s future completes - which is when
  /// that transition *starts* - rebuilt the outgoing dialog against a disposed
  /// controller ("A TextEditingController was used after being disposed").
  /// Seed the field with [initialValue] and read the text back through
  /// [onChanged] instead; the internally created controller then lives and
  /// dies with the field.
  final String? initialValue;

  /// Focus node for controlling focus (optional)
  final FocusNode? focusNode;

  /// Label text (floats above field when focused or has value)
  final String? label;

  /// Hint text (shown when field is empty)
  final String? hintText;

  /// Helper text (shown below field)
  final String? helperText;

  /// Error text (shown below field in the error treatment, overriding
  /// whatever [validator] says)
  final String? errorText;

  /// The meaning of an optional leading mark.
  final IconRole? prefixIcon;

  /// The meaning of an optional trailing mark.
  final IconRole? suffixIcon;

  /// Makes [suffixIcon] the field's action - a picker, a lookup, a generator.
  ///
  /// Material puts an action that belongs to a field inside it as a trailing
  /// icon. Without this the suffix was decorative only, which forced call sites
  /// to add a separate button underneath the field: two affordances for one job,
  /// and one of them detached from the field it belongs to.
  final VoidCallback? onSuffixTap;

  /// What the trailing action does, for its tooltip. Required in spirit
  /// whenever [onSuffixTap] is set: an icon-only control has to name itself.
  final String? suffixTooltip;

  /// How loudly the field asserts itself; see [TextFieldVariant].
  final TextFieldVariant variant;

  /// Whether text should be obscured (for passwords)
  final bool obscureText;

  /// Show clear button when field has text.
  ///
  /// A statement that the field CAN be emptied, not an instruction to draw a
  /// cross: whether the affordance is visible while the field is empty, and
  /// what it looks like, is the language's own answer.
  final bool showClearButton;

  /// Show password visibility toggle (only if obscureText is true)
  final bool showPasswordToggle;

  /// Maximum number of lines (1 for single line)
  final int maxLines;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when field is submitted (Enter key)
  final ValueChanged<String>? onSubmitted;

  /// Validator function.
  ///
  /// The field registers with an enclosing [Form], so
  /// `formKey.currentState!.validate()` runs this validator, shows its message
  /// inline on the field, and returns false while the input is invalid — the
  /// contract every dialog's primary action and Enter handler rely on. The
  /// registration is `SkinFormFieldHost`'s, in one place for every skin,
  /// precisely because a language whose canonical text control knows nothing
  /// about forms must not be able to forget it. After the first user edit the
  /// field also re-validates live on every change, so an error appears (and
  /// clears) at the keystroke that caused it.
  final String? Function(String?)? validator;

  /// Whether to autofocus this field
  final bool autofocus;

  /// Whether field is enabled
  final bool enabled;

  /// Whether Escape in a non-empty field clears it (keeping focus there), so
  /// an empty field lets Escape bubble on to the innermost dismiss scope.
  ///
  /// This is the "clear the text" rung of the Escape ladder and the default.
  /// Disable it where Escape must always mean leaving the surface — a
  /// destructive confirmation's token field, where a fleeing user must not
  /// need a second Escape.
  final bool escapeClears;

  /// What KIND of asking this is, as the contract names it.
  ///
  /// A hidden answer is a password whatever else the caller said about
  /// emphasis: obscuring is a fact about the ANSWER, and every language
  /// reaches for a different canonical control for it, while the emphasis
  /// rungs only choose between two renderings of the same one.
  FieldPurpose get _purpose => obscureText
      ? FieldPurpose.password
      : switch (variant) {
          TextFieldVariant.bordered => FieldPurpose.text,
          TextFieldVariant.emphasized => FieldPurpose.search,
        };

  /// The one action that belongs inside this field.
  ///
  /// The precedence is the one this component always had — reveal, then
  /// clear, then the caller's own action — now expressed as a single slot
  /// rather than as an if/else chain building three different widgets, which
  /// is what makes "never two affordances for one job" unsayable instead of
  /// merely discouraged.
  FieldAffordance? get _affordance {
    if (showPasswordToggle && obscureText) return const FieldRevealAffordance();
    if (showClearButton) return const FieldClearAffordance();
    if (suffixIcon == null) return null;
    return FieldActionAffordance(
      icon: suffixIcon!,
      // A mark-only control has to name itself, and every call site that gives
      // the suffix a handler already names it. The label is the honest
      // fallback if one ever does not: it says which field the action belongs
      // to rather than inventing a verb.
      tooltip: suffixTooltip ?? label ?? '',
      // A suffix with no handler is an action that cannot be taken. Stating it
      // that way keeps the mark and makes its inertness visible, instead of
      // drawing something that looks like a button and does nothing.
      onPressed: onSuffixTap,
    );
  }

  @override
  Widget build(BuildContext context) => Fields.text(
    context,
    FieldSpec(
      // An empty label is a field with no floating label rather than a label
      // with no words; the skin reads it that way, and a search box inside an
      // overlay names itself with its hint.
      label: label ?? '',
      purpose: _purpose,
      hint: hintText,
      helper: helperText,
      error: errorText,
      validator: validator,
      leading: prefixIcon,
      suffix: _affordance,
      maxLines: maxLines,
      enabled: enabled,
      autofocus: autofocus,
      escapeClears: escapeClears,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    ),
    handles: FieldHandles(
      controller: controller,
      focusNode: focusNode,
      initialValue: initialValue,
    ),
  );
}
