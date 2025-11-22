import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Badge visual variants
enum BadgeVariant {
  /// Gray/default - for neutral information
  neutral,

  /// Primary color - for primary status
  primary,

  /// Green - for success, ahead commits, etc.
  success,

  /// Yellow/orange - for warnings, uncommitted changes
  warning,

  /// Red - for errors, conflicts
  danger,

  /// Blue - for information, tips
  info,
}

/// Badge size variants
enum BadgeSize {
  /// Compact size
  small,

  /// Default size
  medium,

  /// Prominent size
  large,
}

/// Base badge component for all badge patterns in the app.
///
/// Provides unified badge behavior with variants and sizes.
///
/// Example usage:
/// ```dart
/// BaseBadge(
///   label: 'New',
///   variant: BadgeVariant.success,
///   size: BadgeSize.medium,
///   icon: PhosphorIconsRegular.check,
///   onDeleted: () => print('Badge deleted'),
/// )
/// ```
class BaseBadge extends StatelessWidget {
  const BaseBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.size = BadgeSize.medium,
    this.icon,
    this.isPill = true,
    this.onDeleted,
  });

  /// Badge text label
  final String label;

  /// Visual variant (neutral, primary, success, warning, danger, info)
  final BadgeVariant variant;

  /// Size variant (small, medium, large)
  final BadgeSize size;

  /// Leading icon (optional)
  final IconData? icon;

  /// Whether to use pill shape (true) or rounded corners (false)
  final bool isPill;

  /// Optional callback for making the badge deletable (shows close icon)
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get size-specific values
    final double horizontalPadding;
    final double verticalPadding;
    final double fontSize;
    final double iconSize;
    final double borderRadius;

    switch (size) {
      case BadgeSize.small:
        horizontalPadding = AppTheme.paddingS;
        verticalPadding = 2;
        fontSize = 10;
        iconSize = 10;
        borderRadius = isPill ? 12 : AppTheme.radiusS;
        break;
      case BadgeSize.medium:
        horizontalPadding = AppTheme.paddingM;
        verticalPadding = 4;
        fontSize = 12;
        iconSize = 12;
        borderRadius = isPill ? 16 : AppTheme.radiusS;
        break;
      case BadgeSize.large:
        horizontalPadding = AppTheme.paddingL;
        verticalPadding = AppTheme.paddingS;
        fontSize = 14;
        iconSize = 14;
        borderRadius = isPill ? 20 : AppTheme.radiusM;
        break;
    }

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary.withValues(alpha: 0.15);
        foregroundColor = colorScheme.primary;
        break;
      case BadgeVariant.success:
        backgroundColor = AppTheme.gitAdded.withValues(alpha: 0.15);
        foregroundColor = AppTheme.gitAdded;
        break;
      case BadgeVariant.warning:
        backgroundColor = AppTheme.gitModified.withValues(alpha: 0.15);
        foregroundColor = AppTheme.gitModified;
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error.withValues(alpha: 0.15);
        foregroundColor = colorScheme.error;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary.withValues(alpha: 0.15);
        foregroundColor = colorScheme.primary;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: foregroundColor),
            SizedBox(width: AppTheme.paddingS / 2),
          ],
          // ignore: avoid_text_with_style
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: fontSize,
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDeleted != null) ...[
            SizedBox(width: AppTheme.paddingS / 2),
            GestureDetector(
              onTap: onDeleted,
              child: Icon(
                Icons.close,
                size: iconSize + 2,
                color: foregroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Numeric badge variant for displaying counts
///
/// Example usage:
/// ```dart
/// BaseNumericBadge(
///   count: 42,
///   variant: BadgeVariant.primary,
/// )
/// ```
class BaseNumericBadge extends StatelessWidget {
  const BaseNumericBadge({
    super.key,
    required this.count,
    this.variant = BadgeVariant.primary,
    this.maxCount = 99,
  });

  /// Count to display
  final int count;

  /// Visual variant
  final BadgeVariant variant;

  /// Maximum count to show (displays "{maxCount}+" for larger numbers)
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.success:
        backgroundColor = AppTheme.gitAdded;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.warning:
        backgroundColor = AppTheme.gitModified;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        // ignore: avoid_text_with_style
        child: Text(
          displayText,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Icon badge variant for displaying a badge overlay on an icon or widget
///
/// Example usage:
/// ```dart
/// BaseIconBadge(
///   count: 5,
///   variant: BadgeVariant.danger,
///   child: Icon(Icons.notifications),
/// )
/// ```
class BaseIconBadge extends StatelessWidget {
  const BaseIconBadge({
    super.key,
    required this.count,
    required this.child,
    this.variant = BadgeVariant.danger,
    this.maxCount = 99,
  });

  /// Count to display in the badge
  final int count;

  /// Widget to display the badge on (typically an icon)
  final Widget child;

  /// Visual variant
  final BadgeVariant variant;

  /// Maximum count to show (displays "{maxCount}+" for larger numbers)
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.success:
        backgroundColor = AppTheme.gitAdded;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.warning:
        backgroundColor = AppTheme.gitModified;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();

    // ignore: avoid_badge
    return Badge(
      // ignore: avoid_text_with_style
      label: Text(
        displayText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

/// Dot badge variant for small status indicators
///
/// Example usage:
/// ```dart
/// BaseDotBadge(
///   variant: BadgeVariant.success,
///   size: 10,
/// )
/// ```
class BaseDotBadge extends StatelessWidget {
  const BaseDotBadge({
    super.key,
    this.variant = BadgeVariant.success,
    this.size = 8.0,
  });

  /// Visual variant (determines color)
  final BadgeVariant variant;

  /// Dot size in pixels
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get variant-specific color
    Color color;

    switch (variant) {
      case BadgeVariant.neutral:
        color = colorScheme.onSurfaceVariant;
        break;
      case BadgeVariant.primary:
        color = colorScheme.primary;
        break;
      case BadgeVariant.success:
        color = AppTheme.gitAdded;
        break;
      case BadgeVariant.warning:
        color = AppTheme.gitModified;
        break;
      case BadgeVariant.danger:
        color = colorScheme.error;
        break;
      case BadgeVariant.info:
        color = colorScheme.primary;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
