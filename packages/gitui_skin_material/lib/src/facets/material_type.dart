import 'package:flutter/material.dart' hide MaterialType;
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../material_glyphs.dart';
import '../material_ink.dart';
import '../material_theme.dart';

/// Things you read, the Material way.
///
/// Three members, moved here from the fifteen `Base*Label` classes in
/// `base_label.dart`, the glyph sites, and the per-line span construction in
/// `base_diff_viewer.dart`. The two mappings they resolve against -
/// `MaterialTypeScale` for the nine application roles onto Material's
/// fifteen-role ramp, `MaterialGlyphs` for the 151 icon roles onto Phosphor -
/// live in `material_ink.dart` and `material_glyphs.dart`, so this facet
/// holds no table of its own.
final class MaterialType implements SkinType {
  /// Builds the type facet.
  const MaterialType();

  /// One piece of text, in the role's ramp step and the tone's colour.
  ///
  /// The neutral colour is NOT `onSurface` spelled out. It is whatever the
  /// enclosing surface has already published through its [DefaultTextStyle],
  /// which this reaches by leaving the colour off the style and letting
  /// `Text`'s own merge supply it. That is the correction `BaseLabel` carried,
  /// moved with its reason: spelling `onSurface` out unconditionally is what
  /// made labels paint straight over the surface they sit on - a selected card
  /// or list row swaps its container for a tonal colour and publishes the
  /// matching foreground through a `DefaultTextStyle`, and a label that ignores
  /// it puts the unselected role back on the selected container, 4.13 : 1 in
  /// the dark theme. Inheriting keeps every state the enclosing surface
  /// resolves, and changes nothing on a plain surface, where the inherited
  /// colour is `onSurface` anyway.
  @override
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
  }) {
    // At [Tone.neutral] the colour is LEFT OUT of the style rather than read
    // out of the ambient one and copied back in. That is not a shortcut; it is
    // the only version of "follow the surface" that also works while the
    // surface is MOVING.
    //
    // `Text` merges the ambient `DefaultTextStyle` underneath whatever style it
    // is handed, so a ramp step carrying no colour of its own already renders
    // in the enclosing surface's foreground - which is the whole of what the
    // neutral tone means, and is exactly what a bare `Text` does. Reading that
    // colour with `DefaultTextStyle.of(context)` gave the same pixels on a
    // still frame and failed on a moving one for two compounding reasons: the
    // read registers a dependency, so every label rebuilt on every tick of any
    // ancestor's text-style animation, and each rebuild re-stamped the
    // interpolated colour, handing `RenderParagraph` a span differing from the
    // last only in paint. Flutter's paint-only fast path then recreates the
    // paragraph mid-paint and asserts its size is unchanged
    // (`TextPainter.paint`, `assert(debugSize == size)`), which it is not while
    // the surrounding layout is animating too. A `NavigationRail` destination
    // lerping its label colour is enough to reach it.
    //
    // Not reading the ambient style here is necessary but NOT sufficient:
    // `Text` itself depends on `DefaultTextStyle` and merges the ambient
    // colour into its span on every tick of an ancestor's text-style
    // animation - `Material` wraps its child in an `AnimatedDefaultTextStyle`
    // over `kThemeChangeDuration`, so every theme change puts every neutral
    // label under a moving colour for 200ms. Because the ramp step pins every
    // layout-affecting attribute, those per-tick spans differ from the last
    // in paint only, which sends `RenderParagraph` down the engine's
    // paint-only fast path - and that path recreates an ELLIPSIZED paragraph
    // mid-paint at a size it did not have, tripping `TextPainter.paint`'s
    // `assert(debugSize == size)`. Measured, not feared: the shell toolbar
    // regression test failed on exactly a two-line ellipsized card label the
    // frame after its config landed.
    //
    // The repair is [_effectiveColourKey]: the one `Text` below is KEYED on
    // the colour it will effectively paint in, so a colour change replaces
    // the element - a fresh `RenderParagraph`, laid out before it paints -
    // instead of updating the old one, and the paint-only path cannot be
    // entered at all. The cost is re-inflating one leaf per colour tick
    // during a transition, which is the same order of work the fast path
    // itself does (it too rebuilds the paragraph), without the assert.
    final TextStyle? ramp = _roleStyle(context, role);
    final Color? stamped = tone == Tone.neutral
        ? null
        : MaterialInk.foreground(context, tone);
    final TextStyle? style = tone == Tone.neutral
        ? _withoutColour(ramp)
        : ramp?.copyWith(color: stamped);
    if (selectable) {
      // The one-value copyable case - a hash, a path, a statistic - which the
      // application renders with `SelectableText` today. A `SelectableText`
      // always wraps within its line box, so `softWrap` has no slot here; no
      // measured selectable site sets it to false. It is also never
      // ellipsized, so it does not need the colour key below.
      return SelectableText(
        value,
        style: style,
        textAlign: align,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
    }
    return _EffectiveColourKeyedText(
      value,
      stamped: stamped,
      style: style,
      align: align,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }

  /// What this skin does when the text does not fit the lines it was given.
  ///
  /// **Only where the caller capped the lines**, and the qualification is the
  /// whole of it. `TextOverflow.ellipsis` is not decoration bolted onto a
  /// paragraph: Flutter's own contract says the ellipsis is applied "to the
  /// first line that is wider than the width constraint, if `maxLines` is
  /// null" (`painting/text_painter.dart`), so an unconditional ellipsis does
  /// not mark a truncation - it CAUSES one, collapsing every wrapping
  /// paragraph in the application to a single cut line. Measured under this
  /// skin: the same prose in a 200 px box renders `Size(200.0, 133.0)` with
  /// the ellipsis off and `Size(200.0, 19.0)` with it on.
  ///
  /// So the two halves of the question are split exactly where the contract
  /// splits them. WHETHER the text is confined is the application's fact and
  /// it says it with `maxLines` (or by refusing to wrap at all); WHAT the
  /// confinement looks like when the words run out of room is this language's
  /// idiom, and Material's answer is an ellipsis at the end - where AppKit
  /// truncates a path in the MIDDLE (`NSLineBreakByTruncatingMiddle`). That
  /// is why `overflow` is not on `SkinType.text` and never becomes a
  /// parameter again.
  ///
  /// Uncapped text falls to `TextOverflow.clip`, which is `Text`'s own
  /// default and is a no-op on a paragraph that is free to wrap: there is no
  /// first over-wide line to clip. It bites only on a line the application
  /// itself refused to break, which is the [softWrap] case above it.
  static TextOverflow _truncation({
    required int? maxLines,
    required bool softWrap,
  }) =>
      maxLines != null || !softWrap ? TextOverflow.ellipsis : TextOverflow.clip;

  /// One idea, drawn as this skin's glyph for it.
  ///
  /// The neutral tone leaves the colour null so the glyph takes the ambient
  /// [IconTheme] - exactly what a bare `Icon(PhosphorIconsRegular.x)` does in
  /// the application today, and what keeps a glyph inside a button or a menu
  /// row following that control's own state colours instead of overpainting
  /// them.
  @override
  Widget icon(
    BuildContext context,
    IconRole role, {
    Tone tone = Tone.neutral,
    ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  }) => Icon(
    MaterialGlyphs.of(role),
    size: MaterialSpacing.glyph(scale),
    color: tone == Tone.neutral ? null : MaterialInk.foreground(context, tone),
    semanticLabel: semanticsLabel,
  );

  /// One line whose stretches mean different things.
  ///
  /// The line's base style is the role's; each run resolves its tone to a
  /// colour on top of it, and an emphasised run takes the semibold weight -
  /// which is the same answer `MaterialTypeScale` gives for
  /// [TextRole.emphasis], so a run that must stand out and a line that must
  /// stand out cannot disagree about what standing out looks like.
  @override
  Widget runs(
    BuildContext context,
    List<TextRun> runs, {
    required TextRole role,
    bool selectable = false,
  }) {
    final Color neutral =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final TextSpan span = TextSpan(
      style: _roleStyle(context, role)?.copyWith(color: neutral),
      children: <InlineSpan>[
        for (final TextRun run in runs)
          TextSpan(
            text: run.text,
            style: run.tone == Tone.neutral && !run.emphasised
                ? null
                : TextStyle(
                    color: run.tone == Tone.neutral
                        ? null
                        : MaterialInk.foreground(context, run.tone),
                    fontWeight: run.emphasised ? FontWeight.w600 : null,
                  ),
          ),
      ],
    );
    // Diff lines are copied constantly, so the selectable path is the live
    // one: the application's diff viewer renders every line selectable.
    return selectable ? SelectableText.rich(span) : Text.rich(span);
  }

  /// [style] with its own colour removed, so that `Text`'s merge lets the
  /// ambient `DefaultTextStyle` supply one.
  ///
  /// Written out field by field because `TextStyle.copyWith` cannot clear a
  /// value: `copyWith(color: null)` keeps the colour it already had, which is
  /// the ramp's `onSurface` and is exactly the wrong answer on a selected
  /// container. There is no `TextStyle.without`, so this is the only way to say
  /// "everything about this ramp step except which colour it is".
  static TextStyle? _withoutColour(TextStyle? style) => style == null
      ? null
      : TextStyle(
          // `inherit: true` is required rather than copied, and it is what
          // makes the whole arrangement work: `Text` only merges the ambient
          // `DefaultTextStyle` when the style it was handed inherits, and the
          // ramp steps this theme builds do not. Every other field is carried
          // over explicitly below, and a merge lets the more specific style
          // win, so the only thing inheriting can now supply is the one thing
          // deliberately left out.
          inherit: true,
          backgroundColor: style.backgroundColor,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontStyle: style.fontStyle,
          letterSpacing: style.letterSpacing,
          wordSpacing: style.wordSpacing,
          textBaseline: style.textBaseline,
          height: style.height,
          leadingDistribution: style.leadingDistribution,
          locale: style.locale,
          foreground: style.foreground,
          background: style.background,
          shadows: style.shadows,
          fontFeatures: style.fontFeatures,
          fontVariations: style.fontVariations,
          decoration: style.decoration,
          decorationColor: style.decorationColor,
          decorationStyle: style.decorationStyle,
          decorationThickness: style.decorationThickness,
          debugLabel: style.debugLabel,
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
          overflow: style.overflow,
        );

  /// The style [role] takes, with the code role resolved against the user's
  /// own monospace family.
  ///
  /// Delegated rather than resolved here, and that is the repair. While this
  /// was a private helper of this facet, `surfaces.codeLine` and
  /// `surfaces.codeBlock` went to the ramp directly - so one skin answered
  /// `TextRole.code` with the user's monospace family here and with the
  /// proportional interface family there. `MaterialTypeResolution` is the
  /// single door now, and this facet has no privileged answer of its own.
  static TextStyle? _roleStyle(BuildContext context, TextRole role) =>
      MaterialTypeResolution.styleOf(context, role);
}

/// One `Text`, keyed on the colour it will effectively paint in.
///
/// This exists for exactly one reason, explained at its call site in
/// [MaterialType.text]: a span that changes ONLY in colour sends
/// `RenderParagraph` down the engine's paint-only fast path, and that path
/// recreates an ellipsized paragraph mid-paint at a size it did not have
/// (`TextPainter.paint`, `assert(debugSize == size)`). Keying the [Text] on
/// the effective colour turns every colour change into a fresh element and a
/// fresh render object, laid out before it paints, so the fast path is never
/// entered.
///
/// It is a widget of its own rather than a key computed in the facet so that
/// the ambient read stays as narrow as it can be: only this leaf depends on
/// `DefaultTextStyle`, and only when nothing is stamped - a toned label keys
/// on its stamped colour and never registers the dependency at all.
class _EffectiveColourKeyedText extends StatelessWidget {
  const _EffectiveColourKeyedText(
    this.value, {
    required this.stamped,
    required this.style,
    required this.align,
    required this.maxLines,
    required this.softWrap,
    required this.semanticsLabel,
  });

  final String value;

  /// The colour the facet stamped for a non-neutral tone; null when the
  /// ambient `DefaultTextStyle` supplies the colour through `Text`'s merge.
  final Color? stamped;

  final TextStyle? style;
  final TextAlign? align;
  final int? maxLines;
  final bool softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final Color? effective =
        stamped ?? DefaultTextStyle.of(context).style.color;
    // ignore: avoid_text_with_style
    return Text(
      value,
      key: ValueKey<Color?>(effective),
      style: style,
      textAlign: align,
      // This skin's truncation idiom, applied only where the caller confined
      // the text. See [MaterialType._truncation] for why the qualification is
      // load-bearing rather than cautious.
      overflow: MaterialType._truncation(
        maxLines: maxLines,
        softWrap: softWrap,
      ),
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }
}
