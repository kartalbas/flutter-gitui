// FROZEN COPY - do not "improve".
//
//   source:  lib/shared/components/base_button.dart
//   sha:     f9ca5b2820ca01f18bbb7734be88bb31a51bfdce
//   copied:  2026-08-06
//
// Permitted edits, and the complete list of them:
//   1. imports retargeted to `../app_stubs.dart` (AppTheme, gitColors);
//   2. classes renamed BaseButton -> FrozenBaseButton and BaseIconButton ->
//      FrozenBaseIconButton, a pure rename so the report can never confuse a
//      frozen copy with the live component. No parameter is added, removed or
//      retyped; the enums keep their names;
//   3. exactly ONE dispatch line per build(), marked `SKIN DISPATCH`;
//   4. the long-form doc comments are condensed. They document Material-
//      specific rationale (BTN-001..006, ICO-001..005 deviation ids), which is
//      not part of the signature under test. Every `final` declaration - the
//      actual public surface - is verbatim.
//
// Anything a skin would additionally need is recorded in FINDINGS.md instead of
// being edited in here. That recording is the measurement.
//
// ignore_for_file: avoid_filled_button, avoid_outlined_button, avoid_text_button, avoid_icon_button

import 'package:flutter/material.dart';

import '../app_stubs.dart';
import '../skin.dart';

/// Button visual variants
enum ButtonVariant {
  /// Filled with primary color - for primary actions
  primary,

  /// Outlined with secondary color - for secondary actions
  secondary,

  /// Text only, subtle - for tertiary actions
  tertiary,

  /// Red/destructive color - for dangerous actions
  danger,

  /// Transparent, hover only - for minimal actions
  ghost,

  /// Green/success color - for positive actions (git bisect good, success states)
  success,

  /// Red outlined - for destructive secondary actions
  dangerSecondary,
}

/// Button size variants
enum ButtonSize {
  /// Compact, for tight spaces
  small,

  /// Default size
  medium,

  /// Prominent actions
  large,
}

/// Base button component for all button patterns in the app.
class FrozenBaseButton extends StatelessWidget {
  const FrozenBaseButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// Button text label
  final String label;

  /// Visual variant (primary, secondary, tertiary, danger, ghost)
  final ButtonVariant variant;

  /// Size variant (small, medium, large)
  final ButtonSize size;

  /// Leading icon (optional)
  final IconData? leadingIcon;

  /// Trailing icon (optional)
  final IconData? trailingIcon;

  /// Whether button is in loading state (shows spinner)
  final bool isLoading;

  /// Whether button is disabled
  final bool isDisabled;

  /// Whether button should expand to full width
  final bool fullWidth;

  ButtonStyle _variantStyle(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color disabledForeground = colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final Color disabledContainer = colorScheme.onSurface.withValues(
      alpha: 0.12,
    );

    switch (variant) {
      case ButtonVariant.primary:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.danger:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.success:
        final Color added = context.gitColors.added;
        return FilledButton.styleFrom(
          backgroundColor: added,
          foregroundColor: GitSemanticColors.foregroundOn(added),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.secondary:
        return OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.dangerSecondary:
        return OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          disabledForegroundColor: disabledForeground,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: disabledContainer);
            }
            return BorderSide(color: colorScheme.error);
          }),
        );
      case ButtonVariant.tertiary:
        return TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.ghost:
        return TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  Widget _content(BuildContext context, double iconSize) {
    final Widget labelText = Text(label);
    final bool hasTrailing = trailingIcon != null && !isLoading;
    if (!isLoading && leadingIcon == null && !hasTrailing) {
      return labelText;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppTheme.paddingS,
      children: [
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          )
        else if (leadingIcon != null)
          Icon(leadingIcon),
        labelText,
        if (hasTrailing) Icon(trailingIcon),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.button(this); // SKIN DISPATCH
    // dart format on

    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isEffectivelyDisabled =
        isDisabled || isLoading || onPressed == null;
    final VoidCallback? effectiveOnPressed = isEffectivelyDisabled
        ? null
        : onPressed;

    final (
      TextStyle? labelStyle,
      double iconSize,
      Size minimumSize,
      EdgeInsetsGeometry? padding,
    ) = switch (size) {
      ButtonSize.small => (
        textTheme.labelMedium,
        AppTheme.iconS,
        const Size(48, 32),
        const EdgeInsets.symmetric(horizontal: AppTheme.paddingM),
      ),
      ButtonSize.medium => (
        textTheme.labelLarge,
        18.0,
        const Size(64, 40),
        null,
      ),
      ButtonSize.large => (
        textTheme.labelLarge,
        18.0,
        const Size(64, 48),
        null,
      ),
    };

    final ButtonStyle style = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
      iconSize: WidgetStatePropertyAll<double>(iconSize),
      minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
      padding: padding == null
          ? null
          : WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_variantStyle(context));

    final Widget child = _content(context, iconSize);

    final Widget button = switch (baseOf(variant)) {
      MaterialBase.filled => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      MaterialBase.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      MaterialBase.text => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };

    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// The three Material button families the variants map onto.
///
/// FINDING: this enum is private in the source (`_MaterialBase`). It is
/// unprivated here ONLY so the Material skin can reuse the identical mapping;
/// it is not part of the public API under test and no skin outside Material
/// reads it.
enum MaterialBase { filled, outlined, text }

MaterialBase baseOf(ButtonVariant variant) {
  switch (variant) {
    case ButtonVariant.primary:
    case ButtonVariant.danger:
    case ButtonVariant.success:
      return MaterialBase.filled;
    case ButtonVariant.secondary:
    case ButtonVariant.dangerSecondary:
      return MaterialBase.outlined;
    case ButtonVariant.tertiary:
    case ButtonVariant.ghost:
      return MaterialBase.text;
  }
}

/// Icon-only button component for compact spaces.
class FrozenBaseIconButton extends StatelessWidget {
  const FrozenBaseIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.variant = ButtonVariant.ghost,
    this.size = ButtonSize.medium,
    this.isDisabled = false,
    this.isSelected,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// Icon to display
  final IconData icon;

  /// Tooltip text (optional)
  final String? tooltip;

  /// Visual variant
  final ButtonVariant variant;

  /// Size variant
  final ButtonSize size;

  /// Whether button is disabled
  final bool isDisabled;

  /// Marks a toggle-style button's state, mirroring [IconButton.isSelected].
  final bool? isSelected;

  ButtonStyle _variantStyle(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color disabledForeground = colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final Color disabledContainer = colorScheme.onSurface.withValues(
      alpha: 0.12,
    );

    switch (variant) {
      case ButtonVariant.primary:
        return IconButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.danger:
        return IconButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.success:
        final Color added = context.gitColors.added;
        return IconButton.styleFrom(
          backgroundColor: added,
          foregroundColor: GitSemanticColors.foregroundOn(added),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.secondary:
        return IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.dangerSecondary:
        return IconButton.styleFrom(
          foregroundColor: colorScheme.error,
          disabledForegroundColor: disabledForeground,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: disabledContainer);
            }
            return BorderSide(color: colorScheme.error);
          }),
        );
      case ButtonVariant.tertiary:
      case ButtonVariant.ghost:
        return IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.iconButton(this); // SKIN DISPATCH
    // dart format on

    final bool isEffectivelyDisabled = isDisabled || onPressed == null;
    final VoidCallback? effectiveOnPressed = isEffectivelyDisabled
        ? null
        : onPressed;

    final (double containerSize, double iconSize) = switch (size) {
      ButtonSize.small => (32.0, AppTheme.iconS),
      ButtonSize.medium => (40.0, AppTheme.iconM),
      ButtonSize.large => (48.0, AppTheme.iconL),
    };

    ButtonStyle style = ButtonStyle(
      iconSize: WidgetStatePropertyAll<double>(iconSize),
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(containerSize)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(AppTheme.paddingS),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_variantStyle(context));

    if (isSelected ?? false) {
      final ColorScheme colorScheme = Theme.of(context).colorScheme;
      final Color disabledForeground = colorScheme.onSurface.withValues(
        alpha: 0.38,
      );
      style = style.copyWith(
        iconColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledForeground;
          }
          return colorScheme.primary;
        }),
      );
    }

    return switch (baseOf(variant)) {
      MaterialBase.filled => IconButton.filled(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
      MaterialBase.outlined => IconButton.outlined(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
      MaterialBase.text => IconButton(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
    };
  }
}
