import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import 'base_menu_item.dart';

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
/// Provides unified button behavior with variants and sizes.
/// Uses theme's color scheme for consistent styling across all color themes.
///
/// ## Size Standards
/// - **Small**: 14px icons, labelSmall text, compact padding (tight spaces)
/// - **Medium**: 16px icons, labelLarge text, standard padding (default)
/// - **Large**: 18px icons, titleMedium text, prominent padding (primary actions)
///
/// ## Variant Standards
/// - **Primary**: Filled with primary color - for primary actions
/// - **Secondary**: Outlined with secondary color - for secondary actions
/// - **Tertiary**: Text only, subtle - for tertiary actions
/// - **Danger**: Red/destructive color - for dangerous actions (delete, discard)
/// - **Ghost**: Transparent, hover only - for minimal actions
/// - **Success**: Green/success color - for positive actions (git bisect good)
/// - **DangerSecondary**: Red outlined - for destructive secondary actions
///
/// ## Icon Guidelines
/// - Use leading icons for actions (check, plus, arrow)
/// - Use trailing icons for navigation/expansion (arrowRight, caretDown)
/// - Icons are automatically sized based on button size
/// - Icons use same color as label for consistency
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEffectivelyDisabled = isDisabled || isLoading || onPressed == null;

    // Get size-specific values
    final double horizontalPadding;
    final double verticalPadding;
    final double iconSize;

    switch (size) {
      case ButtonSize.small:
        horizontalPadding = AppTheme.paddingM;
        verticalPadding = AppTheme.paddingS;
        iconSize = 14;
        break;
      case ButtonSize.medium:
        horizontalPadding = AppTheme.paddingL;
        verticalPadding = AppTheme.paddingM;
        iconSize = 16;
        break;
      case ButtonSize.large:
        horizontalPadding = AppTheme.paddingXL;
        verticalPadding = AppTheme.paddingL;
        iconSize = 18;
        break;
    }

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;
    Color? borderColor;

    if (isEffectivelyDisabled) {
      // Disabled state
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
          backgroundColor = AppTheme.gitAdded;
          foregroundColor = colorScheme.onPrimary;
          borderColor = null;
          break;
        case ButtonVariant.dangerSecondary:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.error;
          borderColor = colorScheme.error;
          break;
      }
    }

    Widget buttonChild = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(foregroundColor),
            ),
          ),
          SizedBox(width: AppTheme.paddingS),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize, color: foregroundColor),
          SizedBox(width: AppTheme.paddingS),
        ],
        // Use MenuItemLabel for consistent clickable label styling
        MenuItemLabel(
          label,
          color: foregroundColor,
          fontWeight: FontWeight.w500,
        ),
        if (trailingIcon != null && !isLoading) ...[
          SizedBox(width: AppTheme.paddingS),
          Icon(trailingIcon, size: iconSize, color: foregroundColor),
        ],
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: InkWell(
          onTap: isEffectivelyDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: buttonChild,
          ),
        ),
      ),
    );
  }
}

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
          backgroundColor = AppTheme.gitAdded;
          foregroundColor = colorScheme.onPrimary;
          borderColor = null;
          break;
        case ButtonVariant.dangerSecondary:
          backgroundColor = colorScheme.surface.withValues(alpha: 0);
          foregroundColor = colorScheme.error;
          borderColor = colorScheme.error;
          break;
      }
    }

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
            border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, size: iconSize, color: foregroundColor),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
