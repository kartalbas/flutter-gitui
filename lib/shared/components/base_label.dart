import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

// The migration bridge. Thirteen Material-named label classes still have call
// sites outside `lib/shared/`, and they are re-exported from here so that every
// file which already imports `base_label.dart` keeps compiling while those
// sites convert. The export line and the file behind it are deleted together,
// the moment the last call site is gone; nothing new may reach for them.

/// The application's way of saying one piece of text.
///
/// **This is a façade** (#249, §2.11) over `type.text`, and it is the same
/// repair [BaseIcon] made for glyphs, applied to the thing the application says
/// far more often. Until now the label layer was thirteen classes named after
/// Material's type scale — `BodyMediumLabel`, `TitleSmallLabel`,
/// `LabelLargeLabel` — and a class with that name has already picked Material's
/// ramp for Fluent and for AppKit. `docs/SKIN-CONTRACT-MEMBERS.md` §10 calls
/// that the substitution failure the whole contract exists to prevent: a call
/// site naming `bodyMedium` is not describing its text, it is quoting one
/// design language's answer about it.
///
/// What crosses the seam here is only the question:
///
///  * [role] — *what is this text FOR?* The name of a screen, the name of one
///    object, a supporting detail, a badge count. Never which step of a ramp:
///    the nine [TextRole] members are the jobs this application's text actually
///    does, and each skin maps them onto its own typography.
///  * [tone] — *what does it MEAN?* `Tone.danger`, not `colorScheme.error`.
///    [Tone.neutral] takes whatever the enclosing surface has already published
///    through its `DefaultTextStyle`, which is what keeps a label inside a
///    selected card or a selected row following that surface's own foreground
///    instead of painting the unselected role back over it.
///
/// Three parameters the old classes carried are deliberately gone, and each
/// absence is a decision rather than an oversight:
///
///  * `style:` — a `TextStyle` at a call site IS the design decision the
///    contract removes. Every site that had one is now a role.
///  * `color:` — a `Color` is an answer, [tone] is the question. An override
///    that could not be named as a meaning was a design decision living in a
///    screen, and removing it is the point rather than a regression.
///  * `overflow:` — how a language truncates is that language's idiom, not the
///    application's: Material ellipsizes at the end, AppKit truncates a path in
///    the MIDDLE. The application still says how many lines it will give the
///    text ([maxLines]); what happens when the text exceeds them is the skin's.
///
/// A site whose text is genuinely part of a larger member — a button's words, a
/// list row's title, a menu entry — belongs on that member's spec instead and
/// moves there as its component migrates. This is for the text that stands on
/// its own.
class BaseLabel extends StatelessWidget {
  /// Says [text] in the [role]'s voice.
  const BaseLabel(
    this.text, {
    super.key,
    required this.role,
    this.tone = Tone.neutral,
    this.align,
    this.maxLines,
    this.softWrap = true,
    this.selectable = false,
    this.semanticsLabel,
  }) : // `identical` rather than `!=`, because [Tone] carries a custom `==`
       // (it has to: `Tone.series` compares an index too) and a constant
       // expression may only use primitive equality. Every named tone is a
       // const singleton, so identity is exactly as strong as equality here
       // and it is the one form a `const BaseLabel(...)` can evaluate.
       assert(
         role != TextRole.emphasis || !identical(tone, Tone.muted),
         'TextRole.emphasis says "this must stand out from the prose beside '
         'it" and Tone.muted says "this is secondary to what it sits beside". '
         'One line cannot be both, and a skin handed both gets a '
         'contradiction rather than an instruction. This pairing arrived by '
         'translating a 15 px label plus an onSurfaceVariant colour word for '
         'word; the meaning underneath was almost always an empty state\'s '
         'explanation, which is TextRole.body carrying Tone.muted.',
       );

  /// The words.
  final String text;

  /// What the text is for. See [TextRole].
  final TextRole role;

  /// What the text means. Neutral takes the enclosing surface's foreground.
  final Tone tone;

  /// How the line sits in the space it was given. Null leaves the decision to
  /// the ambient text direction, which is the right answer nearly everywhere.
  final TextAlign? align;

  /// How many lines the application is willing to spend. What happens at the
  /// last one is the skin's truncation idiom, not a parameter here.
  final int? maxLines;

  /// Whether the text may break across lines at all. False is the single-line
  /// case a dense row wants, where wrapping would push its neighbours around.
  final bool softWrap;

  /// Whether the user can select and copy the text. Behaviour rather than
  /// appearance, which is why it survives the collapse of everything else.
  final bool selectable;

  /// The name assistive technology reads, where it must differ from [text] —
  /// an abbreviation, a glyph-like count, a duration written as `3d`.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.type.text(
          inner,
          text,
          role: role,
          tone: tone,
          maxLines: maxLines,
          align: align,
          softWrap: softWrap,
          selectable: selectable,
          semanticsLabel: semanticsLabel,
        );
      });
}
