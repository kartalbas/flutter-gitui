import 'package:flutter/material.dart';

/// Base component for all clickable menu items in the application.
///
/// This ensures consistent font sizing across all menus (popup menus, dropdowns, etc.)
/// by automatically applying the user's selected font size preference.
///
/// All menu items should use this component to maintain visual consistency.
class BaseMenuItem<T> extends PopupMenuItem<T> {
  const BaseMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.mouseCursor,
    super.labelTextStyle,
    required Widget child,
  }) : super(
          child: child,
        );
}

/// Base component for menu item content with icon and label
///
/// This is the recommended way to build menu item content as it ensures
/// consistent layout and spacing across all menus.
class MenuItemContent extends StatelessWidget {
  const MenuItemContent({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    this.iconSize = 16,
    this.spacing = 8,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabelColor = labelColor ?? theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: spacing),
        Expanded(
          // ignore: avoid_text_with_style
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: effectiveLabelColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Base component for menu item content with a checkmark for selected items
///
/// Use this for menu items that show a selection state (like language selector,
/// theme selector, etc.)
class MenuItemContentWithCheck extends StatelessWidget {
  const MenuItemContentWithCheck({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    this.iconColor,
    this.labelColor,
    this.iconSize = 16,
    this.spacing = 8,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color? iconColor;
  final Color? labelColor;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabelColor = labelColor ?? (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);
    final effectiveIconColor = iconColor ?? (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: effectiveIconColor,
        ),
        SizedBox(width: spacing),
        Expanded(
          // ignore: avoid_text_with_style
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: effectiveLabelColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isSelected) ...[
          SizedBox(width: spacing),
          Icon(
            Icons.check,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

/// Base component for two-line menu item content (icon + primary + secondary text)
///
/// Use this for menu items that need to display additional information below the
/// main label (like switchers showing name + path, or name + commit message)
class MenuItemContentTwoLine extends StatelessWidget {
  const MenuItemContentTwoLine({
    super.key,
    required this.icon,
    required this.primaryLabel,
    this.secondaryLabel,
    this.iconColor,
    this.primaryLabelColor,
    this.secondaryLabelColor,
    this.isSelected = false,
    this.showCheck = false,
    this.iconSize = 16,
    this.spacing = 8,
  });

  final IconData icon;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color? iconColor;
  final Color? primaryLabelColor;
  final Color? secondaryLabelColor;
  final bool isSelected;
  final bool showCheck;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePrimaryColor = primaryLabelColor ?? (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);
    final effectiveIconColor = iconColor;
    final effectiveSecondaryColor = secondaryLabelColor ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: effectiveIconColor,
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ignore: avoid_text_with_style
              Text(
                primaryLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: effectivePrimaryColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (secondaryLabel != null && secondaryLabel!.isNotEmpty)
                // ignore: avoid_text_with_style
                Text(
                  secondaryLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (showCheck && isSelected) ...[
          SizedBox(width: spacing),
          Icon(
            Icons.check,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

/// Base component for simple text labels in buttons and other clickable elements
///
/// Use this for button labels to ensure consistent font scaling with user preferences.
/// This automatically uses the theme's text styles and respects the global font size.
class MenuItemLabel extends StatelessWidget {
  const MenuItemLabel(
    this.text, {
    super.key,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;

    // ignore: avoid_text_with_style
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: effectiveColor,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
