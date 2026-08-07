import 'package:flutter/widgets.dart';

import '../vocabulary.dart';

/// One stretch of text whose meaning differs from its neighbours'.
///
/// The application knows which SPANS mean what - this part is an intra-line
/// edit, that part is the search hit, this word is a path - and knows nothing
/// about what any of that looks like. It replaces the `RichText`/`TextSpan`
/// construction the diff viewer does by hand today, which is application code
/// choosing weights and colours one span at a time.
@immutable
final class TextRun {
  /// Declares one run.
  const TextRun(this.text, {this.tone = Tone.neutral, this.emphasised = false});

  /// The characters.
  final String text;

  /// What this stretch means relative to the rest of the line.
  final Tone tone;

  /// Whether this stretch must stand out from the runs beside it. A statement
  /// of prominence, not of weight: one language answers with weight, another
  /// with a fill behind it.
  final bool emphasised;
}
