// FROZEN COPY - do not "improve".
//
//   source:  lib/shared/components/base_text_field.dart
//   sha:     a078563e220d2fa458f7d6bfdce536e18e4c4080
//   copied:  2026-08-06
//
// Permitted edits, and the complete list of them:
//   1. imports retargeted to `../app_stubs.dart` and `frozen_base_button.dart`;
//   2. class renamed BaseTextField -> FrozenBaseTextField (pure rename);
//   3. exactly ONE dispatch line in build(), marked `SKIN DISPATCH`;
//   4. long-form doc comments condensed. Every `final` declaration - the
//      actual public surface - is verbatim, including `TextFieldVariant`.
//
// ignore_for_file: avoid_text_field

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_stubs.dart';
import '../skin.dart';
import 'frozen_base_button.dart';

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
class FrozenBaseTextField extends StatefulWidget {
  const FrozenBaseTextField({
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
  final VoidCallback? onSuffixTap;

  /// What the trailing action does, for its tooltip.
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

  /// Validator function, run by the enclosing [Form].
  final String? Function(String?)? validator;

  /// Whether to autofocus this field
  final bool autofocus;

  /// Whether field is enabled
  final bool enabled;

  /// Whether Escape in a non-empty field clears it (keeping focus there).
  final bool escapeClears;

  @override
  State<FrozenBaseTextField> createState() => _FrozenBaseTextFieldState();
}

class _FrozenBaseTextFieldState extends State<FrozenBaseTextField> {
  late TextEditingController _controller;
  bool _obscureText = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscureText = widget.obscureText;
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(FrozenBaseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      _controller =
          widget.controller ?? TextEditingController(text: widget.initialValue);
      _controller.addListener(_onTextChanged);
      _hasText = _controller.text.isNotEmpty;
    }
    if (widget.obscureText != oldWidget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
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
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.textField(TextFieldSlot(widget: widget, controller: _controller, obscureText: _obscureText, hasText: _hasText, clearText: _clearText, togglePasswordVisibility: _togglePasswordVisibility)); // SKIN DISPATCH
    // dart format on

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    Widget? suffixIconWidget;

    if (widget.showPasswordToggle && widget.obscureText) {
      suffixIconWidget = FrozenBaseIconButton(
        icon: _obscureText
            ? PhosphorIconsRegular.eye
            : PhosphorIconsRegular.eyeSlash,
        onPressed: _togglePasswordVisibility,
        tooltip: _obscureText ? l10n.showPassword : l10n.hidePassword,
        size: ButtonSize.small,
      );
    } else if (widget.showClearButton && _hasText) {
      suffixIconWidget = FrozenBaseIconButton(
        icon: PhosphorIconsRegular.x,
        onPressed: _clearText,
        tooltip: l10n.clear,
        size: ButtonSize.small,
      );
    } else if (widget.suffixIcon != null) {
      suffixIconWidget = widget.onSuffixTap == null
          ? Icon(widget.suffixIcon, size: 20)
          : FrozenBaseIconButton(
              icon: widget.suffixIcon!,
              onPressed: widget.enabled ? widget.onSuffixTap : null,
              tooltip: widget.suffixTooltip,
              size: ButtonSize.small,
            );
    }

    InputDecoration decoration;

    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );

    switch (widget.variant) {
      case TextFieldVariant.standard:
        decoration = InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          hintStyle: hintStyle,
          helperText: widget.helperText,
          errorText: widget.errorText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20)
              : null,
          suffixIcon: suffixIconWidget,
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.outline, width: 1),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          disabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.38),
              width: 1,
            ),
          ),
        );
        break;

      case TextFieldVariant.outlined:
        decoration = InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          hintStyle: hintStyle,
          helperText: widget.helperText,
          errorText: widget.errorText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20)
              : null,
          suffixIcon: suffixIconWidget,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.outline, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.38),
              width: 1,
            ),
          ),
        );
        break;

      case TextFieldVariant.filled:
        decoration = InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          hintStyle: hintStyle,
          helperText: widget.helperText,
          errorText: widget.errorText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20)
              : null,
          suffixIcon: suffixIconWidget,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide.none,
          ),
        );
        break;
    }

    return GestureDetector(
      onDoubleTap: () {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
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
        child: TextFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          decoration: decoration,
          obscureText: _obscureText,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
