/// The thirteen Material-named label classes, kept alive only until the last
/// call site outside `lib/shared/` has moved onto [BaseLabel]'s roles.
///
/// **This file has an end date and nothing in it is a pattern to copy.** Each
/// class here is named after a step of Material's type ramp, which is exactly
/// the defect #249 removes: a screen that writes `BodyMediumLabel` has chosen
/// Material's typography for Fluent and for AppKit as well, and no amount of
/// re-skinning underneath can take that choice back
/// (`docs/SKIN-CONTRACT-MEMBERS.md` §10). The replacement says what the text is
/// FOR — `TextRole.body`, `TextRole.sectionTitle`, `TextRole.micro` — and lets
/// each design language answer in its own ramp.
///
/// They are quarantined in a file of their own, rather than left beside the
/// façade, so that "how much of the migration is left" is a single number
/// anyone can measure (`grep -c` over the names below) and so that finishing it
/// is deleting one file and one `export` line rather than editing a file that
/// also holds live code. They still render exactly what they rendered before
/// the collapse, on purpose: a bridge that changed sizes would move goldens for
/// call sites nobody had converted yet, and then nobody could tell an intended
/// size change from an accident.
///
/// The four classes that had no call site at all — `DisplayLargeLabel`,
/// `DisplayMediumLabel`, `DisplaySmallLabel` and `HeadlineLargeLabel` — are not
/// here. They existed only to be rendered by the type-scale golden scene, and a
/// class the application never says is not a bridge to anywhere.
library;

import 'package:flutter/material.dart';

import 'base_label.dart';

/// One legacy label, rendered the way the whole family rendered before the
/// collapse.
///
/// The thirteen classes below differ only in which ramp step they hand over, so
/// the body they shared is written once here instead of thirteen times. It
/// keeps the inherited-colour rule the family already carried: the caller's
/// colour first, then whatever the enclosing surface published through its
/// `DefaultTextStyle`, and `onSurface` only where nothing did — spelling
/// `onSurface` out unconditionally is what made a label paint straight over the
/// selected container it sat on, at 4.13 : 1 in the dark theme.
class _RampLabel extends StatelessWidget {
  const _RampLabel(
    this.text, {
    required this.style,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor =
        color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
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

/// Large title (20 px). Replaced by `TextRole.pageTitle`.
class TitleLargeLabel extends StatelessWidget {
  /// Says [text] at Material's `titleLarge`.
  const TitleLargeLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit. The skin's answer once migrated.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.titleLarge,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Medium title (16 px). Replaced by `TextRole.sectionTitle` or
/// `TextRole.itemTitle`, depending on whether it names a region or an object.
class TitleMediumLabel extends StatelessWidget {
  /// Says [text] at Material's `titleMedium`.
  const TitleMediumLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.titleMedium,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Small title (14 px). The class that splits hardest: it named a region at
/// most sites (`TextRole.sectionTitle`) and one object at the rest
/// (`TextRole.itemTitle`).
class TitleSmallLabel extends StatelessWidget {
  /// Says [text] at Material's `titleSmall`.
  const TitleSmallLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.titleSmall,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Medium headline (24 px). Replaced by `TextRole.pageTitle`.
class HeadlineMediumLabel extends StatelessWidget {
  /// Says [text] at Material's `headlineMedium`.
  const HeadlineMediumLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.headlineMedium,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Small headline (22 px). Replaced by `TextRole.pageTitle`.
class HeadlineSmallLabel extends StatelessWidget {
  /// Says [text] at Material's `headlineSmall`.
  const HeadlineSmallLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.headlineSmall,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Large body (15 px). Replaced by `TextRole.emphasis`, because the sites that
/// used it were saying "this line matters more than the prose beside it" with
/// size, and Material's own answer to that is weight.
class BodyLargeLabel extends StatelessWidget {
  /// Says [text] at Material's `bodyLarge`.
  const BodyLargeLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.bodyLarge,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Medium body (13 px), the family's most-said member. Replaced by
/// `TextRole.body`.
class BodyMediumLabel extends StatelessWidget {
  /// Says [text] at Material's `bodyMedium`.
  const BodyMediumLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.bodyMedium,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Small body (12 px). Replaced by `TextRole.detail`.
class BodySmallLabel extends StatelessWidget {
  /// Says [text] at Material's `bodySmall`.
  const BodySmallLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.bodySmall,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Large label (14 px). Replaced by `TextRole.control` at the field labels it
/// was written for.
class LabelLargeLabel extends StatelessWidget {
  /// Says [text] at Material's `labelLarge`.
  const LabelLargeLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.labelLarge,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Medium label (12 px). Replaced by `TextRole.detail`, or `TextRole.micro`
/// where it was drawing a pill.
class LabelMediumLabel extends StatelessWidget {
  /// Says [text] at Material's `labelMedium`.
  const LabelMediumLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.labelMedium,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Small label (11 px). Replaced by `TextRole.micro`.
class LabelSmallLabel extends StatelessWidget {
  /// Says [text] at Material's `labelSmall`.
  const LabelSmallLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  /// The words.
  final String text;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: Theme.of(context).textTheme.labelSmall,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// A label whose style the call site handed over as a `TextStyle`.
///
/// This is the old `BaseLabel` under a name that says what it is, and it is the
/// most direct statement of the defect in the whole file: a `TextStyle` at a
/// call site is a design decision that no skin can take back. Every site that
/// used it becomes a role, and several of them also lose an italic, a
/// `FontWeight.bold` or a `TextDecoration.lineThrough` — each of which was a
/// design language's answer to a question the call site should only have asked.
class StyledLabel extends StatelessWidget {
  /// Says [text] in whatever [style] the caller decided on.
  const StyledLabel(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  });

  /// The words.
  final String text;

  /// The caller's own type decision.
  final TextStyle? style;

  /// The colour that becomes a `Tone` on [BaseLabel].
  final Color? color;

  /// How the line sits in its space.
  final TextAlign? textAlign;

  /// What happens when the text does not fit.
  final TextOverflow? overflow;

  /// How many lines the text may take.
  final int? maxLines;

  /// Whether the text may break across lines.
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => _RampLabel(
    text,
    style: style,
    color: color,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
    softWrap: softWrap,
  );
}
