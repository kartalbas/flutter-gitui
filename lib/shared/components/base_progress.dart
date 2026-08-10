import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The application's way of saying "this is under way".
///
/// **This is a façade** (#249, §2.11): the body is one delegation to
/// `controls.progress`, and everything a Material `CircularProgressIndicator`
/// or `LinearProgressIndicator` used to decide here — whether the mark is a
/// ring or a bar at all, its diameter or thickness, its stroke, its end caps
/// and its track — is the skin's. Material draws a ring; Fluent draws its own;
/// macOS draws something that is not a ring.
///
/// Two things stay with the caller, and neither is appearance.
///
/// [fraction] is what the application knows: a number between zero and one, or
/// **null when the end is genuinely unknowable**. That distinction is not a
/// styling choice — it is the difference between "half done" and "still
/// working", and the contract records that one language cannot draw the second
/// case in its bar form at all, as a registered loss rather than a hand-painted
/// lookalike.
///
/// [extent] is how much room saying so may take. `inline` is a mark inside a
/// line of content — beside a label, within a button, along an edge.
/// `block` is a region of its own with nothing else competing for the space,
/// which is what a pane says while its content loads.
///
/// Getting that rung wrong is the mistake to watch for: Material answers
/// `block` with a centred ring and `inline` with a full-width bar, so a busy
/// mark squeezed into a row while stating `block` grows to fill the pane, and a
/// loading pane stating `inline` becomes a hairline across the top.
class BaseProgress extends StatelessWidget {
  /// How far along, or null when the end cannot be known.
  final double? fraction;

  /// How much room saying so may take.
  final ProgressExtent extent;

  const BaseProgress({super.key, this.fraction, required this.extent});

  /// A mark inside a line of content, with an unknowable end — the common case.
  const BaseProgress.inline({super.key, this.fraction})
    : extent = ProgressExtent.inline;

  /// A region of its own, with an unknowable end — what a pane shows while its
  /// content loads.
  const BaseProgress.block({super.key, this.fraction})
    : extent = ProgressExtent.block;

  @override
  Widget build(BuildContext context) => SkinScope.render(context, (
    Skin skin,
    BuildContext inner,
  ) {
    return skin.controls.progress(inner, fraction: fraction, extent: extent);
  });
}
