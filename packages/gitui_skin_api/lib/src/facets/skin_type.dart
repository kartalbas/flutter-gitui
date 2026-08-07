import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../specs/type_specs.dart';
import '../vocabulary.dart';

/// Things you read.
///
/// Three members. `selectionScope` is deliberately absent: `SelectableRegion`
/// comes from `package:flutter/widgets.dart` and selectability is BEHAVIOUR -
/// what the user can do - which the Zero Test keeps in application reach. The
/// only design in it is the selection toolbar, which each skin already
/// supplies from inside its own text implementation.
abstract interface class SkinType {
  /// **What job is this piece of text doing, and what does it mean?**
  ///
  /// The role says what the text is FOR in this application's words - the name
  /// of a screen, the name of one object, a supporting detail - and never
  /// which step of a type ramp it takes. A screen that named a ramp step would
  /// have picked one language's typography for all of them.
  Widget text(
    BuildContext context,
    String value, {
    required TextRole role,
    Tone tone = Tone.neutral,
    int? maxLines,
    TextAlign? align,
    bool softWrap = true,
    bool selectable = false,
    String? semanticsLabel,
  });

  /// **Which idea does this mark stand for?**
  ///
  /// Never which glyph. Keeping `IconData` would have been type-neutral but
  /// not identity-neutral, and every skin would render the same icon set
  /// forever - the hand-painted-lookalike failure moved from geometry onto
  /// iconography.
  Widget icon(
    BuildContext context,
    IconRole role, {
    Tone tone = Tone.neutral,
    ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  });

  /// **Which parts of this line mean something different from the rest?**
  ///
  /// The application knows which SPANS mean what - an intra-line edit, a
  /// search hit, a stretch of inline code - and nothing about what any of them
  /// looks like.
  Widget runs(
    BuildContext context,
    List<TextRun> runs, {
    required TextRole role,
    bool selectable = false,
  });
}
