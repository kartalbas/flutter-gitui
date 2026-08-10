import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_ink.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';

/// Things you read, the Fluent way.
///
/// Three members over the foundations already in `fluent_typography.dart`:
/// the Windows 11 ramp (`FluentTypeRamp`), the nine-roles-onto-four-rungs
/// judgement (`FluentTypeScale`) and the single resolution door
/// (`FluentTypeResolution`). This facet holds no table of its own - every
/// style it renders walks through the door, so the user's families and
/// scales land here without this file knowing them.
///
/// **Colour follows the surface.** The ramp deliberately carries no colour,
/// so a neutral line renders in whatever foreground the enclosing surface
/// published through its `DefaultTextStyle` - the correction the Material
/// skin's facet documents at length (a stamped `onSurface` paints the
/// unselected role straight over a selected container). Fluent needs none
/// of Material's colour-keyed repair machinery for it, because nothing in
/// this skin animates a default text style: `FluentTheme` is a plain
/// inherited widget, so an ambient colour change is a discrete rebuild with
/// a fresh layout, never a paint-only tick.
///
/// **The registered glyph-table gap applies here.** `icon` reserves its
/// exact box on the published Fluent icon ramp and draws nothing in it -
/// the same decision every [IconRole] slot in the controls facet records
/// (see `FluentButton`'s doc): tracing 151 glyphs by hand would be
/// inventing an icon set, and a wrong-looking mark would be worse than a
/// visibly pending one. The day the table lands, the mark drops into a box
/// that never moved.
final class FluentType implements SkinType {
  /// Builds the type facet.
  const FluentType();

  /// One piece of text, in the role's ramp step and the tone's colour.
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
    final TextStyle step = FluentTypeResolution.styleOf(context, role);
    // At Tone.neutral the colour is LEFT OUT: the step inherits, so `Text`'s
    // own merge lets the enclosing surface's DefaultTextStyle supply the
    // foreground - which is the whole of what neutral means. Only a
    // non-neutral tone reads the theme, and only `muted` reads the ambient
    // style, because its meaning is relative to what it sits beside
    // (FluentInk.mutedBeside).
    final TextStyle style = tone == Tone.neutral
        ? step
        : step.copyWith(color: _toneColor(context, tone));
    final Widget line = Text(
      value,
      style: style,
      textAlign: align,
      maxLines: maxLines,
      softWrap: softWrap,
      // This language's truncation idiom, applied only where the caller
      // confined the text - see [_truncation].
      overflow: _truncation(maxLines: maxLines, softWrap: softWrap),
      semanticsLabel: semanticsLabel,
    );
    return selectable ? _selectable(context, line) : line;
  }

  /// What this skin does when the text does not fit the lines it was given.
  ///
  /// **Only where the caller capped the lines.** Flutter's ellipsis does not
  /// mark a truncation, it CAUSES one on any paragraph free to wrap - the
  /// measured collapse the Material facet documents - so an unconditional
  /// ellipsis would rewrite every wrapping paragraph into one cut line.
  /// WHETHER text is confined is the application's fact, stated through
  /// `maxLines` or by refusing to wrap; WHAT confinement looks like is this
  /// language's idiom, and Windows trims a confined text block at a
  /// character boundary with an ellipsis at the END - XAML
  /// `TextTrimming.CharacterEllipsis`, "text is trimmed at a character
  /// boundary; an ellipsis (...) is drawn in place of remaining text"
  /// (Windows.UI.Xaml.TextTrimming). Uncapped text falls to `clip`, `Text`'s
  /// own default, which is a no-op on a paragraph that is free to wrap.
  static TextOverflow _truncation({
    required int? maxLines,
    required bool softWrap,
  }) =>
      maxLines != null || !softWrap ? TextOverflow.ellipsis : TextOverflow.clip;

  /// One idea's mark: its exact box on the Fluent icon ramp, with the glyph
  /// itself pending the registered glyph table.
  ///
  /// The box is `FluentSpacing.glyph` - the published 12/16/20 icon ramp -
  /// so geometry, alignment and the accessible name are all final now. The
  /// tone is not dropped: it resolves to the same foreground every drawn
  /// mark will take and rides an [IconTheme] over the slot, exactly the
  /// arrangement `FluentIconButton` keeps for its own pending glyph, so the
  /// table lands into both slots the same way.
  @override
  Widget icon(
    BuildContext context,
    IconRole role, {
    Tone tone = Tone.neutral,
    ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  }) {
    final double extent = FluentSpacing.glyph(scale);
    return Semantics(
      label: semanticsLabel,
      child: IconTheme.merge(
        data: IconThemeData(
          size: extent,
          color: tone == Tone.neutral ? null : _toneColor(context, tone),
        ),
        child: SizedBox.square(dimension: extent),
      ),
    );
  }

  /// One line whose stretches mean different things.
  ///
  /// The line's base style is the role's, resolved through the door and
  /// carrying no colour, so the whole line follows its surface; each run
  /// stamps its tone on top of it. An emphasised run takes Semibold - SPEC,
  /// verbatim: "Use Semibold instead of Bold for emphasis" - which is the
  /// same answer `FluentTypeScale` gives [TextRole.emphasis], so a run that
  /// must stand out and a line that must stand out cannot disagree about
  /// what standing out looks like. Material answers the identical run with
  /// w600 too; the difference lives in the ramp underneath and in the tone
  /// palette, not in the mechanism.
  @override
  Widget runs(
    BuildContext context,
    List<TextRun> runs, {
    required TextRole role,
    bool selectable = false,
  }) {
    final TextSpan span = TextSpan(
      style: FluentTypeResolution.styleOf(context, role),
      children: <InlineSpan>[
        for (final TextRun run in runs)
          TextSpan(
            text: run.text,
            style: run.tone == Tone.neutral && !run.emphasised
                ? null
                : TextStyle(
                    color: run.tone == Tone.neutral
                        ? null
                        : _toneColor(context, run.tone),
                    // SPEC weights table: Semibold is w600.
                    fontWeight: run.emphasised ? FontWeight.w600 : null,
                  ),
          ),
      ],
    );
    final Widget line = Text.rich(span);
    return selectable ? _selectable(context, line) : line;
  }

  /// The foreground [tone] means here, with the ambient foreground supplied
  /// only for the one tone whose meaning is relative to it.
  static Color _toneColor(BuildContext context, Tone tone) =>
      FluentInk.foreground(
        FluentTheme.of(context),
        tone,
        ambientForeground: tone == Tone.muted
            ? DefaultTextStyle.of(context).style.color
            : null,
      );

  /// Makes [child] copyable, with the accent selection wash and no toolbar.
  ///
  /// The wash is the same brush the skin's own text box paints its
  /// selection with (`fluent_text_box.dart`, `selectionColor:
  /// theme.accent.normal` - WinUI selects in the system accent). The
  /// toolbar is the registered flyout gap this package already carries at
  /// the text box: Fluent's text-command surface is a flyout, and the
  /// overlay member that will host one is not this one. Selection itself
  /// works, exactly as it does there.
  static Widget _selectable(BuildContext context, Widget child) =>
      DefaultSelectionStyle(
        selectionColor: FluentTheme.of(context).accent.normal,
        child: SelectableRegion(
          selectionControls: emptyTextSelectionControls,
          child: child,
        ),
      );
}
