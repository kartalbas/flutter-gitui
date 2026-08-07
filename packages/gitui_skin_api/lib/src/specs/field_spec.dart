import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../vocabulary.dart';

/// An action that belongs to a field and therefore lives INSIDE it.
///
/// This repository's rules make that non-negotiable: an action belonging to a
/// field is a trailing affordance in the field, never a free-floating button
/// beside or below it, and never two affordances for one job. Expressing it as
/// a sealed set rather than as three booleans is what lets a language use its
/// OWN affordance where it has one - `MacosTextField.clearButtonMode` is the
/// measured case - instead of being handed a generic mark to draw.
sealed class FieldAffordance {
  /// Const base constructor for the sealed set.
  const FieldAffordance();
}

/// "Empty this field."
///
/// Its own kind rather than an action with a mark, because every language
/// already owns this one and each draws it differently, including deciding
/// when it appears at all.
final class FieldClearAffordance extends FieldAffordance {
  /// Declares the clear affordance.
  const FieldClearAffordance();
}

/// "Show me what I typed."
///
/// Separate from [FieldPurpose.password] because they are two facts: whether
/// the text is hidden, and whether the user is allowed to unhide it.
final class FieldRevealAffordance extends FieldAffordance {
  /// Declares the reveal affordance.
  const FieldRevealAffordance();
}

/// An action only this field has: a folder picker, a lookup, a generator.
final class FieldActionAffordance extends FieldAffordance {
  /// Declares one in-field action.
  const FieldActionAffordance({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  /// The action's mark.
  final IconRole icon;

  /// What it does. Required, because a mark-only control has to name itself.
  final String tooltip;

  /// What happens when it is used. Null disables the affordance while leaving
  /// it visible, so the field does not change shape as the action becomes
  /// available.
  final VoidCallback? onPressed;
}

/// The imperative handles onto a field's live editing state.
///
/// Separate from [FieldSpec] because none of it is a description of the field:
/// a `TextEditingController` and a `FocusNode` are objects with a lifetime,
/// they cannot be `const`, and they are behaviour rather than appearance -
/// which is precisely why the application is allowed to hold them.
@immutable
final class FieldHandles {
  /// Declares the handles, or none at all.
  const FieldHandles({this.controller, this.focusNode, this.initialValue})
    : assert(
        controller == null || initialValue == null,
        'Pass either a controller or an initialValue, not both: the '
        'controller already carries the text the field starts with.',
      );

  /// The application's own handle on the text, where it needs one.
  final TextEditingController? controller;

  /// The application's own handle on the focus, where a screen hands focus
  /// between controls itself.
  final FocusNode? focusNode;

  /// The text the field starts with, for a caller that keeps no controller.
  final String? initialValue;

  /// The text this field starts life holding.
  String get startingText => controller?.text ?? initialValue ?? '';
}

/// What a text field is asking the user for.
///
/// Deliberately not a rename of `InputDecoration`'s slots: written that way it
/// would be Material's field model wearing a neutral name. Each field here is a
/// question the application can answer without knowing what a field looks
/// like - what is it called, what is it for, what does it currently object to,
/// and what can be done inside it.
@immutable
final class FieldSpec {
  /// Declares one text field.
  const FieldSpec({
    required this.label,
    this.purpose = FieldPurpose.text,
    this.hint,
    this.helper,
    this.error,
    this.validator,
    this.leading,
    this.suffix,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.selectable = true,
    this.escapeClears = true,
    this.onChanged,
    this.onSubmitted,
  });

  /// What the field is asking for.
  final String label;

  /// What KIND of asking this is.
  ///
  /// It carries only the values for which a language reaches for a different
  /// canonical widget, which is why there are three of them and not six.
  final FieldPurpose purpose;

  /// An example of an acceptable answer, shown while the field is empty.
  final String? hint;

  /// A standing note about what makes an answer acceptable.
  final String? helper;

  /// What the field objects to right now, where the application knows it from
  /// somewhere other than [validator] - a server's reply, a duplicate name.
  ///
  /// The host below merges this with whatever the validator says, so a skin
  /// only ever sees one message.
  final String? error;

  /// What makes an answer acceptable.
  ///
  /// It lives on the SPEC and not inside the skin, and that is the single most
  /// consequential decision in this file. The pre-P0 gate measured that
  /// `MacosTextField` does not register with a `Form` at all - there is no
  /// `FormField` anywhere in the package, and `validate()` over an empty
  /// required field returns **true**. This repository has already shipped that
  /// exact defect once, where a dialog's `validate()` found no fields and waved
  /// invalid input through. So registration may not be left to each skin to
  /// remember: the validator crosses here as data and [SkinFormFieldHost] does
  /// the registering, once, for every skin.
  final FormFieldValidator<String>? validator;

  /// A mark at the head of the field, naming what is being asked for.
  final IconRole? leading;

  /// The action that belongs to this field.
  final FieldAffordance? suffix;

  /// How many lines of answer the field expects. One means a single line;
  /// more means the answer is prose. A fact about the ANSWER, not a height.
  final int maxLines;

  /// Whether it may be answered right now.
  final bool enabled;

  /// Whether it should take the keyboard when the surface opens. Every dialog
  /// autofocuses its first field, which is a keyboard contract rather than a
  /// look.
  final bool autofocus;

  /// Whether the user can select and copy what is in it.
  final bool selectable;

  /// Whether Escape in a non-empty field empties it rather than leaving the
  /// surface.
  ///
  /// This is the "clear the text" rung of the Escape ladder, and it is
  /// keyboard behaviour rather than appearance - which is why the application
  /// states it and no skin may weaken it. Disable it where Escape must always
  /// mean leaving, such as a destructive confirmation's token field.
  final bool escapeClears;

  /// How to tell the application the answer changed.
  final ValueChanged<String>? onChanged;

  /// How to tell the application the user finished answering.
  final ValueChanged<String>? onSubmitted;

  /// Returns this spec as the host resolved it, for the skin to render.
  ///
  /// Private on purpose: a skin receives the resolved spec and can never
  /// construct one, so it cannot route around the registration.
  FieldSpec _hosted({
    required String? error,
    required ValueChanged<String> onChanged,
  }) => FieldSpec(
    label: label,
    purpose: purpose,
    hint: hint,
    helper: helper,
    error: error,
    validator: validator,
    leading: leading,
    suffix: suffix,
    maxLines: maxLines,
    enabled: enabled,
    autofocus: autofocus,
    selectable: selectable,
    escapeClears: escapeClears,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );
}

/// Builds the skin's own field, from a spec the host has already resolved.
typedef SkinFieldBuilder =
    Widget Function(BuildContext context, FieldSpec spec, FieldHandles handles);

/// The one place a skin's text field is registered with the enclosing `Form`.
///
/// It is the same "impossible to forget" shape the overlay seam uses, and for
/// the same reason. `FormField` comes from `package:flutter/widgets.dart`, not
/// from Material, so hosting it here costs the contract nothing: the
/// compile-time proof that no member requires Material survives intact, and a
/// skin that renders `MacosTextField`, `TextBox` or a bare `EditableText` is
/// registered exactly as a Material `TextFormField` would have been.
///
/// What it does, in order:
///
///  1. opens a `FormField<String>` seeded with the field's starting text and
///     carrying the spec's validator;
///  2. hands the skin a spec whose `error` is the application's own message if
///     there is one and the validator's otherwise, so the skin renders one
///     message and never has to merge two;
///  3. hands the skin an `onChanged` that reports to the form first and to the
///     application second;
///  4. watches the application's controller, if it kept one, so that text set
///     programmatically - a clear affordance, an Escape, a generated value -
///     reaches the form too. Without this a field could be emptied without the
///     form ever hearing about it, which is the original defect in a new
///     costume.
///
/// Validation is live only after the user has interacted, which is the
/// behaviour the application already ships: an error appears, and clears, at
/// the keystroke that caused it, and a form that has never been touched does
/// not greet the user in red.
final class SkinFormFieldHost extends StatelessWidget {
  /// Hosts the field [builder] returns.
  const SkinFormFieldHost({
    super.key,
    required this.spec,
    required this.handles,
    required this.builder,
  });

  /// What the field is asking for, as the application stated it.
  final FieldSpec spec;

  /// The application's handles on the live editing state.
  final FieldHandles handles;

  /// Produces the skin's own field from the resolved spec.
  final SkinFieldBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: handles.startingText,
      validator: spec.validator,
      enabled: spec.enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (FormFieldState<String> field) => _ControllerBridge(
        controller: handles.controller,
        onText: field.didChange,
        child: Builder(
          builder: (BuildContext inner) => builder(
            inner,
            spec._hosted(
              error: spec.error ?? field.errorText,
              onChanged: (String value) {
                field.didChange(value);
                spec.onChanged?.call(value);
              },
            ),
            handles,
          ),
        ),
      ),
    );
  }
}

/// Keeps the hosting form in step with text the application sets itself.
class _ControllerBridge extends StatefulWidget {
  const _ControllerBridge({
    required this.controller,
    required this.onText,
    required this.child,
  });

  final TextEditingController? controller;
  final ValueChanged<String> onText;
  final Widget child;

  @override
  State<_ControllerBridge> createState() => _ControllerBridgeState();
}

class _ControllerBridgeState extends State<_ControllerBridge> {
  String? _lastReported;

  @override
  void initState() {
    super.initState();
    _lastReported = widget.controller?.text;
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(_ControllerBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _lastReported = widget.controller?.text;
      widget.controller?.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  /// Reports only genuine changes, so a rebuild caused by reporting cannot
  /// report again.
  void _handleControllerChanged() {
    final String text = widget.controller?.text ?? '';
    if (text == _lastReported) return;
    _lastReported = text;
    widget.onText(text);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
