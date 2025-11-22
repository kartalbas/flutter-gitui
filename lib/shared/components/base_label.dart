import 'package:flutter/material.dart';

/// Base component for all text labels/titles in the app.
///
/// Automatically applies proper text color based on theme to ensure
/// readability in both light and dark modes.
///
/// IMPORTANT: Instead of using BaseLabel directly with a style,
/// use one of the specialized sub-components below (TitleLargeLabel,
/// BodyMediumLabel, etc.) for consistency and simplicity.
class BaseLabel extends StatelessWidget {
  const BaseLabel(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  });

  /// The text to display
  final String text;

  /// Text style (will have color overridden unless customColor is provided)
  final TextStyle? style;

  /// Custom color (if null, uses theme's onSurface color)
  final Color? color;

  /// Text alignment
  final TextAlign? textAlign;

  /// Text overflow behavior
  final TextOverflow? overflow;

  /// Maximum number of lines
  final int? maxLines;

  /// Whether text should wrap
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use custom color if provided, otherwise use onSurface
    final effectiveColor = color ?? colorScheme.onSurface;

    // ignore: avoid_text_with_style
    return Text(
      text,
      style: style?.copyWith(color: effectiveColor),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
    );
  }
}

// ============================================================================
// TITLE LABELS (for headings and section titles)
// ============================================================================

/// Large title label (22px) - used for dialog titles, main headings
class TitleLargeLabel extends StatelessWidget {
  const TitleLargeLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.titleLarge, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Medium title label (16px) - used for sub-sections
class TitleMediumLabel extends StatelessWidget {
  const TitleMediumLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.titleMedium, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Small title label (14px) - used for panel headers, small section titles
class TitleSmallLabel extends StatelessWidget {
  const TitleSmallLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.titleSmall, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

// ============================================================================
// DISPLAY LABELS (for very large text - rarely used)
// ============================================================================

/// Large display label (57px)
class DisplayLargeLabel extends StatelessWidget {
  const DisplayLargeLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.displayLarge, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Medium display label (45px)
class DisplayMediumLabel extends StatelessWidget {
  const DisplayMediumLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.displayMedium, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Small display label (36px)
class DisplaySmallLabel extends StatelessWidget {
  const DisplaySmallLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.displaySmall, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

// ============================================================================
// HEADLINE LABELS (for large headings - less commonly used)
// ============================================================================

/// Large headline label (32px)
class HeadlineLargeLabel extends StatelessWidget {
  const HeadlineLargeLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.headlineLarge, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Medium headline label (28px)
class HeadlineMediumLabel extends StatelessWidget {
  const HeadlineMediumLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.headlineMedium, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Small headline label (24px)
class HeadlineSmallLabel extends StatelessWidget {
  const HeadlineSmallLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.headlineSmall, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

// ============================================================================
// BODY LABELS (for normal text content)
// ============================================================================

/// Large body label (16px) - used for emphasized body text
class BodyLargeLabel extends StatelessWidget {
  const BodyLargeLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.bodyLarge, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Medium body label (14px) - used for normal body text (most common)
class BodyMediumLabel extends StatelessWidget {
  const BodyMediumLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.bodyMedium, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Small body label (12px) - used for secondary/muted text, captions
class BodySmallLabel extends StatelessWidget {
  const BodySmallLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.bodySmall, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

// ============================================================================
// LABEL LABELS (for UI elements like buttons, badges, etc.)
// ============================================================================

/// Large label (14px) - used for buttons
class LabelLargeLabel extends StatelessWidget {
  const LabelLargeLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.labelLarge, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Medium label (12px) - used for labels
class LabelMediumLabel extends StatelessWidget {
  const LabelMediumLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.labelMedium, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}

/// Small label (11px) - used for small labels, badges
class LabelSmallLabel extends StatelessWidget {
  const LabelSmallLabel(this.text, {super.key, this.color, this.textAlign, this.overflow, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return BaseLabel(text, style: Theme.of(context).textTheme.labelSmall, color: color, textAlign: textAlign, overflow: overflow, maxLines: maxLines);
  }
}
