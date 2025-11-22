import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
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
  });

  /// Text editing controller (optional - will create one if not provided)
  final TextEditingController? controller;

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

  /// Validator function
  final String? Function(String?)? validator;

  /// Whether to autofocus this field
  final bool autofocus;

  /// Whether field is enabled
  final bool enabled;

  @override
  State<BaseTextField> createState() => _BaseTextFieldState();
}

class _BaseTextFieldState extends State<BaseTextField> {
  late TextEditingController _controller;
  bool _obscureText = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _obscureText = widget.obscureText;
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(BaseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      _controller = widget.controller ?? TextEditingController();
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
      // Custom suffix icon
      suffixIconWidget = Icon(
        widget.suffixIcon,
        size: 20,
      );
    }

    // Build InputDecoration based on variant
    InputDecoration decoration;

    // Hint style - make it more subtle and distinct from input text
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
            borderSide: BorderSide(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
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
            borderSide: BorderSide(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
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
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: colorScheme.error,
              width: 2,
            ),
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
        // Select all text on double click
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
      // ignore: avoid_text_field
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        decoration: decoration,
        obscureText: _obscureText,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
