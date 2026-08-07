import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import 'base_button.dart';

/// Text field visual variants
enum TextFieldVariant {
  /// Underline only (minimal)
  standard,

  /// Border all around (default)
  outlined,

  /// Filled background (prominent)
  filled,
}

/// Base component for all text input patterns in the app.
///
/// Provides unified text input behavior with variants and validation.
///
/// Geometry, outline colors per state, typography and the disabled and error
/// treatments are asserted against a real SDK `TextField` by
/// test/conformance/components/base_text_field_conformance_test.dart; the three
/// deliberate divergences are registered as FIELD-001..FIELD-003 in
/// docs/deviation_register.yaml.
///
/// Example usage:
/// ```dart
/// BaseTextField(
///   label: 'Branch name',
///   hintText: 'Enter branch name',
///   prefixIcon: PhosphorIconsRegular.gitBranch,
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
///   prefixIcon: PhosphorIconsRegular.lock,
/// )
/// ```
///
/// Search field example:
/// ```dart
/// BaseTextField(
///   hintText: 'Search repositories...',
///   prefixIcon: PhosphorIconsRegular.magnifyingGlass,
///   showClearButton: true,
///   variant: TextFieldVariant.filled,
/// )
/// ```
class BaseTextField extends StatefulWidget {
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
    this.variant = TextFieldVariant.outlined,
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

  /// Text editing controller (optional - will create one if not provided)
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

  /// Error text (shown below field in red, overrides helperText)
  final String? errorText;

  /// Leading icon (optional)
  final IconData? prefixIcon;

  /// Trailing icon (optional)
  final IconData? suffixIcon;

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

  /// Visual variant (standard, outlined, filled)
  final TextFieldVariant variant;

  /// Whether text should be obscured (for passwords)
  final bool obscureText;

  /// Show clear button when field has text
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
  /// contract every dialog's primary action and Enter handler rely on. After
  /// the first user edit the field also re-validates live on every change, so
  /// an error appears (and clears) at the keystroke that caused it.
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

  @override
  State<BaseTextField> createState() => _BaseTextFieldState();
}

class _BaseTextFieldState extends State<BaseTextField> {
  late TextEditingController _controller;

  /// Whether [_controller] was created here rather than handed in.
  ///
  /// Ownership has to be tracked separately from `widget.controller == null`:
  /// a caller that swaps a controller in later leaves this state holding an
  /// internally created controller that `widget.controller == null` no longer
  /// describes, and disposing on that test alone would leak the one we made
  /// (or, the other way round, dispose one the caller still uses).
  bool _ownsController = false;
  bool _obscureText = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _adoptController();
    _obscureText = widget.obscureText;
  }

  @override
  void didUpdateWidget(BaseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      // What the field currently shows, captured before the old controller is
      // released. It survives only into an internally created replacement: a
      // caller who hands us a controller is handing us its text too, and
      // overwriting that would be the field second-guessing its owner.
      final carriedText = _controller.text;
      _releaseController();
      _adoptController(carriedText: carriedText);
    }
    if (widget.obscureText != oldWidget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  /// Takes the caller's controller, or creates one and remembers that this
  /// state owns it.
  ///
  /// [carriedText] is what the field was showing a moment ago, passed only
  /// when replacing one controller with another. An internally created
  /// replacement continues from it rather than from
  /// [BaseTextField.initialValue]: a caller who stops supplying a controller
  /// is changing who owns the text, not asking for the user's typing to be
  /// thrown away. On the first build there is nothing to carry, so the seed
  /// is [BaseTextField.initialValue].
  void _adoptController({String? carriedText}) {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        TextEditingController(text: carriedText ?? widget.initialValue);
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  /// Detaches from the current controller, disposing it only when this state
  /// created it.
  void _releaseController() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Determine if we should show suffix icon
    Widget? suffixIconWidget;

    if (widget.showPasswordToggle && widget.obscureText) {
      // Password toggle takes priority
      suffixIconWidget = BaseIconButton(
        icon: _obscureText
            ? PhosphorIconsRegular.eye
            : PhosphorIconsRegular.eyeSlash,
        onPressed: _togglePasswordVisibility,
        tooltip: _obscureText ? l10n.showPassword : l10n.hidePassword,
        size: ButtonSize.small,
      );
    } else if (widget.showClearButton && _hasText) {
      // Clear button
      suffixIconWidget = BaseIconButton(
        icon: PhosphorIconsRegular.x,
        onPressed: _clearText,
        tooltip: l10n.clear,
        size: ButtonSize.small,
      );
    } else if (widget.suffixIcon != null) {
      // An action that belongs to this field belongs inside it; only a suffix
      // without a handler stays decorative.
      suffixIconWidget = widget.onSuffixTap == null
          ? Icon(widget.suffixIcon, size: AppTheme.iconM)
          : BaseIconButton(
              icon: widget.suffixIcon!,
              onPressed: widget.enabled ? widget.onSuffixTap : null,
              tooltip: widget.suffixTooltip,
              size: ButtonSize.small,
            );
    }

    // The decoration only decides the border *shape* per variant. The side —
    // its color and width in every state: enabled, hovered, focused, error and
    // disabled — is resolved by InputDecorator from the Material 3 defaults
    // (_InputDecoratorDefaultsM3.outlineBorder, Flutter 3.44.4
    // packages/flutter/lib/src/material/input_decorator.dart:5995), which it
    // does for any border whose side is not BorderSide.none
    // (input_decorator.dart:2266-2283). Hand-writing enabledBorder /
    // errorBorder / disabledBorder here is what used to freeze the field at
    // one color per state: it painted the error outline at the 2 dp weight M3
    // reserves for focus, the disabled outline at `outline` 38% instead of
    // `onSurface` 12%, and dropped the hover indication altogether, because a
    // spelled-out enabledBorder also wins in the hovered state.
    final OutlineInputBorder outlinedShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
    );
    final OutlineInputBorder filledShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      borderSide: BorderSide.none,
    );

    final InputDecoration commonDecoration = InputDecoration(
      labelText: widget.label,
      hintText: widget.hintText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: widget.prefixIcon != null
          ? Icon(widget.prefixIcon, size: AppTheme.iconM)
          : null,
      suffixIcon: suffixIconWidget,
    );

    final InputDecoration decoration = switch (widget.variant) {
      TextFieldVariant.standard => commonDecoration.copyWith(
        border: const UnderlineInputBorder(),
      ),
      TextFieldVariant.outlined => commonDecoration.copyWith(
        border: outlinedShape,
      ),
      // The filled variant is the app's search/inline field: a filled box with
      // no active indicator (FIELD-003) and all four corners rounded
      // (FIELD-002). A border with `BorderSide.none` makes InputDecorator
      // return it unchanged for every state (input_decorator.dart:2266), so
      // the states that must stay visible are spelled out here — and only
      // those.
      TextFieldVariant.filled => commonDecoration.copyWith(
        filled: true,
        border: filledShape,
        disabledBorder: filledShape,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    };

    return GestureDetector(
      onDoubleTap: () {
        // Select all text on double click
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
      // Escape in a filled field clears it and keeps focus there — correcting
      // a typo must not throw the keyboard out of the field. An empty field
      // ignores the key, so it bubbles on to the innermost enclosing dismiss
      // scope (close the dialog, collapse the search, leave the mode): this is
      // the "clear the text" rung of the Escape ladder. The watcher node never
      // takes focus and is not a Tab stop.
      child: Focus(
        debugLabel: 'BaseTextField.escapeToClear',
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (!widget.escapeClears) return KeyEventResult.ignored;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey != LogicalKeyboardKey.escape) {
            return KeyEventResult.ignored;
          }
          if (_controller.text.isEmpty) return KeyEventResult.ignored;
          _clearText();
          return KeyEventResult.handled;
        },
        // A FormField, not a plain TextField: the widget always accepted a
        // validator, but a TextField never runs one, so every dialog's
        // `formKey.currentState!.validate()` found no fields and waved invalid
        // input through. TextFormField registers with the enclosing Form, runs
        // the validator, and shows its message on the field.
        // ignore: avoid_text_field
        child: TextFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          decoration: decoration,
          obscureText: _obscureText,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          // Re-validate on every change once the user has touched the field:
          // the error appears (and clears) at the keystroke that caused it,
          // instead of going stale until the next submit attempt.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          // No `style`: the Material 3 input text role is bodyLarge
          // (text_field.dart:1893, _m3InputStyle) and the SDK also derives the
          // disabled treatment from it — bodyLarge at 38% opacity
          // (text_field.dart:1886-1890). Overriding the style with bodyMedium
          // shrank the text a user types to the size of supporting text and
          // replaced that disabled treatment with a flat color.
        ),
      ),
    );
  }
}
