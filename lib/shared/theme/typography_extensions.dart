import 'package:flutter/material.dart';

/// Typography extensions for consistent text styling across the app
///
/// Usage:
/// ```dart
/// Text('Hello', style: context.textTheme.bodyLarge)
/// Text('Title', style: context.textTheme.titleMedium.bold)
/// Text('Error', style: context.textTheme.bodyMedium.error(context))
/// ```
extension TypographyExtensions on BuildContext {
  /// Quick access to TextTheme from current theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Quick access to ColorScheme from current theme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

/// Text style modifier extensions for easier customization
extension TextStyleModifiers on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text regular weight
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);

  /// Make text light weight
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Make text italic
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);

  /// Apply primary color
  TextStyle primary(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.primary);

  /// Apply secondary color
  TextStyle secondary(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.secondary);

  /// Apply error color
  TextStyle error(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.error);

  /// Apply surface color (good for text on colored backgrounds)
  TextStyle onSurface(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.onSurface);

  /// Apply muted/disabled color
  TextStyle muted(BuildContext context) => copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      );

  /// Apply custom color
  TextStyle colored(Color color) => copyWith(color: color);

  /// Apply custom opacity
  TextStyle withOpacity(double opacity) => copyWith(
        color: color?.withValues(alpha: opacity),
      );

  /// Increase font size by percentage
  TextStyle larger(double factor) => copyWith(
        fontSize: fontSize != null ? fontSize! * factor : null,
      );

  /// Decrease font size by percentage
  TextStyle smaller(double factor) => copyWith(
        fontSize: fontSize != null ? fontSize! / factor : null,
      );

  /// Apply letter spacing
  TextStyle spaced(double spacing) => copyWith(letterSpacing: spacing);

  /// Apply line height
  TextStyle withHeight(double height) => copyWith(height: height);

  /// Apply underline decoration
  TextStyle get underlined =>
      copyWith(decoration: TextDecoration.underline);

  /// Apply line-through decoration
  TextStyle get strikethrough =>
      copyWith(decoration: TextDecoration.lineThrough);

  /// Remove decoration
  TextStyle get noDecoration => copyWith(decoration: TextDecoration.none);
}

/// Semantic text style helpers for common use cases
extension SemanticTextStyles on BuildContext {
  /// Heading styles
  TextStyle get heading1 => textTheme.displayLarge!;
  TextStyle get heading2 => textTheme.displayMedium!;
  TextStyle get heading3 => textTheme.displaySmall!;
  TextStyle get heading4 => textTheme.headlineMedium!;
  TextStyle get heading5 => textTheme.headlineSmall!;
  TextStyle get heading6 => textTheme.titleLarge!;

  /// Body text styles
  TextStyle get bodyLarge => textTheme.bodyLarge!;
  TextStyle get bodyMedium => textTheme.bodyMedium!;
  TextStyle get bodySmall => textTheme.bodySmall!;
  TextStyle get body => textTheme.bodyMedium!; // Default body text

  /// Label styles
  TextStyle get labelLarge => textTheme.labelLarge!;
  TextStyle get labelMedium => textTheme.labelMedium!;
  TextStyle get labelSmall => textTheme.labelSmall!;
  TextStyle get label => textTheme.labelMedium!; // Default label

  /// Title styles
  TextStyle get titleLarge => textTheme.titleLarge!;
  TextStyle get titleMedium => textTheme.titleMedium!;
  TextStyle get titleSmall => textTheme.titleSmall!;
  TextStyle get title => textTheme.titleMedium!; // Default title

  /// Specialized styles
  TextStyle get caption => textTheme.bodySmall!.muted(this);
  TextStyle get overline =>
      textTheme.labelSmall!.copyWith(letterSpacing: 1.5);
  TextStyle get button => textTheme.labelLarge!.medium;

  /// Code/monospace style
  TextStyle get code => textTheme.bodyMedium!.copyWith(
        fontFamily: 'JetBrains Mono',
        fontFeatures: [
          const FontFeature.enable('liga'),
          const FontFeature.enable('zero'),
        ],
      );

  /// Git-specific styles
  TextStyle get commitHash => code.copyWith(
        color: colorScheme.primary.withValues(alpha: 0.8),
      );

  TextStyle get branchName => body.semiBold.primary(this);
  TextStyle get fileName => body.regular;
  TextStyle get filePath => body.muted(this);

  /// Status styles
  TextStyle get success => body.colored(const Color(0xFF4CAF50));
  TextStyle get warning => body.colored(const Color(0xFFFF9800));
  TextStyle get danger => body.error(this);
  TextStyle get info => body.primary(this);
}
