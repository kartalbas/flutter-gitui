// This file is the design system's sanctioned wrapper around the Material
// button widgets: every other file must use BaseButton, and the design-system
// lint bans the raw widgets app-wide so keyboard focus, state layers and tap
// targets cannot be hand-rolled twice. Building the wrapper ON the real
// Material buttons is the point of the component, so the bans are lifted for
// this file only (precedent: base_dialog.dart, base_text_field.dart).
// ignore_for_file: avoid_filled_button, avoid_outlined_button, avoid_text_button

import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

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
///
/// Built on the Material 3 button classes — [FilledButton], [OutlinedButton]
/// and [TextButton] — so every button is keyboard-operable out of the box:
/// Tab reaches it, a focus state layer marks it, and Enter and Space activate
/// it. Divergences from the M3 defaults are registered in
/// docs/deviation_register.yaml (BTN-001..BTN-006) and asserted by
/// test/conformance/components/base_button_conformance_test.dart.
///
/// ## Size Standards
/// Sizes describe the visual container; every size sits inside a >= 48 dp
/// hit area via the padded tap target, so a compact button never shrinks the
/// touch target.
/// - **Small**: 32 dp container (BTN-002), labelMedium text (BTN-003),
///   16 dp icons (BTN-004) — dense rows and banners
/// - **Medium**: the stock M3 button — 40 dp container, labelLarge text,
///   18 dp icons (default)
/// - **Large**: 48 dp container (BTN-005), labelLarge text, 18 dp icons —
///   hero and empty-state actions
///
/// All sizes share the 8 dp control corner (BTN-001) instead of the M3
/// stadium shape.
///
/// ## Variant Standards
/// - **Primary**: filled, primary/onPrimary - for primary actions
/// - **Secondary**: outlined, primary label with outline border - for
///   secondary actions
/// - **Tertiary**: the M3 text button, primary label - for tertiary actions
/// - **Danger**: filled, error/onError - for destructive confirms
/// - **Ghost**: text button with a neutral onSurface label (BTN-006) - for
///   chrome-less repeated actions; unlike tertiary it must not read as a link
/// - **Success**: filled with the git semantic green - for positive actions
///   (git bisect good)
/// - **DangerSecondary**: outlined with error label and border - for
///   destructive secondary actions; the border falls back to the M3 disabled
///   treatment so the error tint never survives into disabled
///
/// ## Icon Guidelines
/// - Use leading icons for actions (check, plus, arrow)
/// - Use trailing icons for navigation/expansion (arrowRight, caretDown)
/// - Icons are automatically sized and colored by the button style
///
/// Example usage:
/// ```dart
/// // Primary action with leading icon
/// BaseButton(
///   label: 'Commit Changes',
///   variant: ButtonVariant.primary,
///   size: ButtonSize.medium,
///   leadingIcon: PhosphorIconsRegular.check,
///   onPressed: () => commitChanges(),
/// )
///
/// // Destructive action
/// BaseButton(
///   label: 'Discard All',
///   variant: ButtonVariant.danger,
///   leadingIcon: PhosphorIconsRegular.trash,
///   onPressed: () => discardAll(),
/// )
///
/// // Loading state
/// BaseButton(
///   label: 'Saving...',
///   variant: ButtonVariant.primary,
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
class BaseButton extends StatelessWidget {
  const BaseButton({
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

  /// The Material button class a variant renders through.
  _MaterialBase get _base {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.danger:
      case ButtonVariant.success:
        return _MaterialBase.filled;
      case ButtonVariant.secondary:
      case ButtonVariant.dangerSecondary:
        return _MaterialBase.outlined;
      case ButtonVariant.tertiary:
      case ButtonVariant.ghost:
        return _MaterialBase.text;
    }
  }

  /// The variant's colors, expressed through the concrete class's
  /// `styleFrom` so the state layers derive from the right foreground with
  /// the M3 opacities (pressed/focused 10%, hovered 8%).
  ///
  /// Every variant shares the M3 disabled treatment (onSurface at 38% for
  /// the foreground, at 12% for filled containers and outlined borders), so
  /// no semantic tint survives into disabled.
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
        // The border is deliberately not pinned: the M3 default side already
        // does the right thing per state (outline enabled, primary focused,
        // onSurface at 12% disabled).
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
        // BTN-006: neutral onSurface instead of the M3 primary, so the
        // chrome-less variant does not read as a link.
        return TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  /// The button content. Text carries no style and icons carry no size or
  /// color: the button style's DefaultTextStyle and IconTheme supply them,
  /// so label, spinner and both icons always match the resolved foreground.
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
              // While loading the button is disabled, so the spinner paints
              // in the M3 disabled foreground like the rest of the content.
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isEffectivelyDisabled =
        isDisabled || isLoading || onPressed == null;
    final VoidCallback? effectiveOnPressed = isEffectivelyDisabled
        ? null
        : onPressed;

    // Per-size metrics. Medium is the stock M3 button; small and large are
    // the registered desktop sizes (BTN-002..BTN-005). Where padding is
    // null the framework's scaled padding applies.
    final (
      TextStyle? labelStyle,
      double iconSize,
      Size minimumSize,
      EdgeInsetsGeometry? padding,
    ) = switch (size) {
      // BTN-002 container, BTN-003 label, BTN-004 icon; the 48 dp minimum
      // width keeps even a one-character small button a full hit target.
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
      // BTN-005 container.
      ButtonSize.large => (
        textTheme.labelLarge,
        18.0,
        const Size(64, 48),
        null,
      ),
    };

    // Every measured property is pinned at the widget so conformance stays
    // deterministic: the app theme overrides the button sub-themes (bodyLarge
    // text style, FlexColorScheme radii and comfortable density), and none of
    // that may leak into the component. The padded tap target plus standard
    // density guarantee the >= 48 dp hit area around every container size.
    final ButtonStyle style = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
      iconSize: WidgetStatePropertyAll<double>(iconSize),
      minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
      padding: padding == null
          ? null
          : WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      // BTN-001: the shared 8 dp control corner instead of the M3 stadium.
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_variantStyle(context));

    final Widget child = _content(context, iconSize);

    final Widget button = switch (_base) {
      _MaterialBase.filled => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      _MaterialBase.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      _MaterialBase.text => TextButton(
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

/// The three Material button classes BaseButton variants map onto.
enum _MaterialBase { filled, outlined, text }

/// Icon-only button variant for compact spaces
///
/// ## Size Standards
/// - **Small**: 32x32px button, 16px icon
/// - **Medium**: 40x40px button, 20px icon (default)
/// - **Large**: 48x48px button, 24px icon
///
/// ## Usage Guidelines
/// - Always provide a tooltip for accessibility
/// - Use ghost variant (default) for toolbar buttons
/// - Use danger variant for destructive icon actions
/// - Use primary variant for affirmative icon actions
///
/// Example usage:
/// ```dart
/// // Toolbar button
/// BaseIconButton(
///   icon: PhosphorIconsRegular.trash,
///   tooltip: 'Delete',
///   variant: ButtonVariant.ghost,
///   onPressed: () => deleteItem(),
/// )
///
/// // Destructive action
/// BaseIconButton(
///   icon: PhosphorIconsRegular.x,
///   tooltip: 'Remove',
///   variant: ButtonVariant.danger,
///   size: ButtonSize.small,
///   onPressed: () => removeItem(),
/// )
/// ```
class BaseIconButton extends StatelessWidget {
  const BaseIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.variant = ButtonVariant.ghost,
    this.size = ButtonSize.medium,
    this.isDisabled = false,
    this.iconColor,
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

  /// Overrides the variant's icon color, so toggle-style buttons can make
  /// their active state (e.g. a favorited star) read unmistakably without
  /// changing the button chrome. Ignored while disabled, because the "on"
  /// tint must never survive into the disabled treatment.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEffectivelyDisabled = isDisabled || onPressed == null;

    // Get size-specific values
    final double buttonSize;
    final double iconSize;

    switch (size) {
      case ButtonSize.small:
        buttonSize = 32;
        iconSize = 16;
        break;
      case ButtonSize.medium:
        buttonSize = 40;
        iconSize = 20;
        break;
      case ButtonSize.large:
        buttonSize = 48;
        iconSize = 24;
        break;
    }

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;
    Color? borderColor;

    if (isEffectivelyDisabled) {
      backgroundColor = colorScheme.surfaceContainerHighest;
      foregroundColor = colorScheme.onSurface.withValues(alpha: 0.38);
      borderColor = null;
    } else {
      switch (variant) {
        case ButtonVariant.primary:
          backgroundColor = colorScheme.primary;
          foregroundColor = colorScheme.onPrimary;
          borderColor = null;
          break;
        case ButtonVariant.secondary:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.secondary;
          borderColor = colorScheme.secondary;
          break;
        case ButtonVariant.tertiary:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.onSurface;
          borderColor = null;
          break;
        case ButtonVariant.danger:
          backgroundColor = colorScheme.error;
          foregroundColor = colorScheme.onError;
          borderColor = null;
          break;
        case ButtonVariant.ghost:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.onSurface;
          borderColor = null;
          break;
        case ButtonVariant.success:
          backgroundColor = context.gitColors.added;
          foregroundColor = GitSemanticColors.foregroundOn(
            context.gitColors.added,
          );
          borderColor = null;
          break;
        case ButtonVariant.dangerSecondary:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.error;
          borderColor = colorScheme.error;
          break;
      }
    }

    final effectiveIconColor = isEffectivelyDisabled
        ? foregroundColor
        : iconColor ?? foregroundColor;

    final button = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      child: InkWell(
        onTap: isEffectivelyDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            border: borderColor != null
                ? Border.all(color: borderColor, width: 2)
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, size: iconSize, color: effectiveIconColor),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
