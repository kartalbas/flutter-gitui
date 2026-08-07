import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// Things you read, naked.
///
/// The blueprint has one type size - whatever the root installed - so nothing
/// here is a ramp. Every meaning a design language would carry in a size, a
/// weight or a glyph is carried as a text mark BESIDE the content, taken from
/// `BlueprintMarks` so this facet and a control rendering the same meaning
/// cannot disagree. The content itself is always its own `Text` widget holding
/// exactly the caller's string, which is what keeps `find.text('Delete')`
/// matching under the instrument: the blueprint never destroys information,
/// only appearance.
///
/// Selection is behaviour, not appearance, so `selectable:` is honoured with
/// `SelectableRegion` - exported from `package:flutter/widgets.dart` - and
/// [emptyTextSelectionControls]. That pairing is decision D4 recorded in
/// `docs/SKIN-CONTRACT.md`: the selection WORKS, and there is no selection
/// toolbar, because the adaptive toolbar is Material/Cupertino and importing
/// it would break the compile-time proof this package exists to carry. The
/// missing toolbar is the blueprint's one registered deviation.
final class BlueprintType implements SkinType {
  /// Takes the distance every rung resolves against.
  const BlueprintType(this.distance);

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance. Type has no rung of its own to resolve - it is
  /// carried so that every facet is constructed the same way.
  final BlueprintDistance distance;

  /// One piece of text, marked with what it is for and what it means.
  ///
  /// The role mark leads and the tone mark follows it, concatenated into a
  /// single mark widget beside the value - `#!` reads as "a page title, and
  /// dangerous". `TextRole.body` at `Tone.neutral` is the unmarked default, so
  /// prose stays prose and the marks that do appear mean something.
  ///
  /// The pair sits in a zero-spacing [Wrap] rather than a row so that a long
  /// value in a narrow place moves below its mark and keeps wrapping instead
  /// of overflowing - a marked line must never lay out worse than the bare
  /// line a design language would draw.
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
    final Widget content = BlueprintText(
      value,
      maxLines: maxLines,
      align: align,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
    final Widget copyable = selectable ? _selectable(content) : content;
    final String mark =
        '${BlueprintMarks.textRole(role)}${BlueprintMarks.tone(tone)}';
    if (mark.isEmpty) return copyable;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[BlueprintMark(mark), copyable],
    );
  }

  /// One idea, drawn as its own name.
  ///
  /// `[gitBranch]` rather than a glyph, because drawing 151 distinguishable
  /// marks would be a glyph set - that is, design - while the role's own name
  /// is more distinguishable than any glyph set and makes a wrong mapping
  /// obvious on sight. The scale cannot change the type size (the blueprint
  /// has one), so it renders as a leading mark of its own: `-` for compact,
  /// nothing for normal, `+` for prominent. The tone mark trails, exactly as
  /// it does on text.
  @override
  Widget icon(
    BuildContext context,
    IconRole role, {
    Tone tone = Tone.neutral,
    ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  }) {
    final String scaleMark = switch (scale) {
      ControlScale.compact => '-',
      ControlScale.normal => BlueprintMarks.none,
      ControlScale.prominent => '+',
    };
    return BlueprintText(
      '$scaleMark${BlueprintMarks.icon(role)}${BlueprintMarks.tone(tone)}',
      semanticsLabel: semanticsLabel,
    );
  }

  /// One line whose stretches mean different things.
  ///
  /// This is the one member that cannot go through `BlueprintText`, because a
  /// line of spans is not a string; the root span carries the same
  /// `BlueprintInk.textStyle` instead, so the discipline - one style,
  /// resolved in one place - holds here too.
  ///
  /// Each run's tone renders as its mark immediately before the run, inside
  /// the same line, because a diff line's meaning lives at exact character
  /// positions and a mark floating elsewhere would not say WHICH stretch it
  /// belongs to. An emphasised run is underlined: the underline is a
  /// one-pixel ink stroke - the blueprint's own vocabulary - and unlike a
  /// bracketing mark it leaves the run's characters exactly where the
  /// neighbouring runs expect them.
  @override
  Widget runs(
    BuildContext context,
    List<TextRun> runs, {
    required TextRole role,
    bool selectable = false,
  }) {
    final String roleMark = BlueprintMarks.textRole(role);
    final List<InlineSpan> spans = <InlineSpan>[
      if (roleMark.isNotEmpty) TextSpan(text: roleMark),
      for (final TextRun run in runs) ...<InlineSpan>[
        if (BlueprintMarks.tone(run.tone).isNotEmpty)
          TextSpan(text: BlueprintMarks.tone(run.tone)),
        TextSpan(
          text: run.text,
          style: run.emphasised
              ? TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: BlueprintInk.ink(context),
                )
              : null,
        ),
      ],
    ];
    final Widget line = Text.rich(
      TextSpan(style: BlueprintInk.textStyle(context), children: spans),
    );
    return selectable ? _selectable(line) : line;
  }

  /// Makes [child] copyable, with no toolbar.
  ///
  /// [emptyTextSelectionControls] is the widgets-layer's own "no handles, no
  /// toolbar" answer, which is decision D4: the behaviour survives, the
  /// Material chrome does not.
  static Widget _selectable(Widget child) => SelectableRegion(
    selectionControls: emptyTextSelectionControls,
    child: child,
  );
}
