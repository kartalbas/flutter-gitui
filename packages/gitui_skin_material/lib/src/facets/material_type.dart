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
  /// and only falls back to `onSurface` where nothing has. This is the
  /// correction `BaseLabel` carries, moved with its reason: spelling
  /// `onSurface` out unconditionally is what made labels paint straight over
  /// the surface they sit on - a selected card or list row swaps its
  /// container for a tonal colour and publishes the matching foreground
  /// through a `DefaultTextStyle`, and a label that ignores it puts the
  /// unselected role back on the selected container, 4.13 : 1 in the dark
  /// theme. Reading the inherited colour keeps every state the enclosing
  /// surface resolves, and changes nothing on a plain surface, where the
  /// inherited colour is `onSurface` anyway.
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
    final Color color = tone == Tone.neutral
        ? (DefaultTextStyle.of(context).style.color ??
              Theme.of(context).colorScheme.onSurface)
        : MaterialInk.foreground(context, tone);
    final TextStyle? style = _roleStyle(context, role)?.copyWith(color: color);
    if (selectable) {
      // The one-value copyable case - a hash, a path, a statistic - which the
      // application renders with `SelectableText` today. A `SelectableText`
      // always wraps within its line box, so `softWrap` has no slot here; no
      // measured selectable site sets it to false.
      return SelectableText(
        value,
        style: style,
        textAlign: align,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
    }
    // ignore: avoid_text_with_style
    return Text(
      value,
      style: style,
      textAlign: align,
      // An ellipsis rather than a clip once the line budget is spent, which
      // is what every `Base*Label` call site that caps its lines expects.
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }

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
