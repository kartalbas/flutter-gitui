import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The application's way of drawing one mark.
///
/// **This is a façade** (#249, §2.11) over `type.icon`, and it is the missing
/// rung of the `Base*` layer: every other component had one — `BaseButton`,
/// `BaseLabel`, `BaseCard` — while a bare glyph was still written as a raw
/// `Icon(PhosphorIconsRegular.x, size: 16, color: …)` at every site. That
/// spelled out three of a design language's answers at once (which glyph, how
/// big, which colour) in application code, which is exactly what the skin
/// contract exists to stop.
///
/// What crosses the seam here is only the question:
///
///  * [role] — *which idea does this mark stand for?* Never which glyph, and
///    never at which weight: Phosphor's Regular/Bold/Fill, a Fluent filled
///    variant and an SF Symbol weight are not the same three things, so the
///    weight is re-decided inside the skin by the facet that knows which slot
///    it is filling (`docs/SKIN-CONTRACT.md` conflict C3).
///  * [tone] — *what does this mark mean?* `Tone.danger`, not
///    `colorScheme.error`. [Tone.neutral] leaves the colour to whatever the
///    enclosing control has already published through its `IconTheme`, which
///    is what a bare `Icon` with no colour did and what keeps a mark inside a
///    button following that button's own state colours.
///  * [scale] — *how much room is it entitled to?* Three coarse rungs rather
///    than a pixel size, for the reason the spike measured: Fluent 2 has one
///    control height, so a number would be unhonourable in two of the three
///    languages.
///
/// A site whose mark is genuinely part of a larger member — a list row's
/// leading mark, a tree node's folder, a toolbar picker's glyph — belongs in
/// that member's spec instead, and will move there as its component migrates.
/// This is for the marks that stand on their own.
class BaseIcon extends StatelessWidget {
  const BaseIcon(
    this.role, {
    super.key,
    this.tone = Tone.neutral,
    this.scale = ControlScale.normal,
    this.semanticsLabel,
  });

  /// The idea the mark stands for.
  final IconRole role;

  /// What the mark means. Neutral takes the ambient foreground.
  final Tone tone;

  /// How much room the mark is entitled to.
  final ControlScale scale;

  /// The name assistive technology reads, where the mark is not already named
  /// by a control around it.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.type.icon(
          inner,
          role,
          tone: tone,
          scale: scale,
          semanticsLabel: semanticsLabel,
        );
      });
}
