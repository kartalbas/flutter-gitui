/// The application's way of saying how far apart things sit.
///
/// **These are façades** (#249, §2.11) over `SkinLayout`, and they are the same
/// repair `BaseIcon` made for glyphs and `BaseLabel` for text, applied to the
/// thing the application says most often of all: 1,046 `AppTheme.padding*`
/// reads, 695 `SizedBox(width:|height:)` gaps and 235 `EdgeInsets` constructors
/// were the application answering, in Material's numbers, questions that three
/// design languages answer three different ways.
///
/// What crosses the seam here is only the question:
///
///  * [BaseGap] — *how closely do these two neighbours belong together?*
///    [Proximity.related] says "a label and the value it names", never "8
///    pixels". The rung is the whole statement; the distance is the skin's.
///  * [BaseInset] — *how much breathing room does this container owe its
///    content?* [Inset.normal] says "the ordinary reading distance of this
///    design language", never "16 pixels".
///  * [BaseSeparator] — *are these two regions about different things?* A
///    statement of division, not a line: a language that divides with space
///    rather than with a rule is answering the same question correctly.
///
/// The reason these are three widgets and not three constants is the one
/// `docs/SKIN-CONTRACT.md` §0 turns on. A token bag — `context.space.m` —
/// moves *where a number comes from* without moving *who decided that a gap
/// exists, where it goes and which rung it takes*, so `context.space.m * 1.5`
/// stays writable and stays layout decided in the application. There is no
/// number here to multiply.
///
/// Two things deliberately have no façade, and both absences are the contract's
/// §1 line rather than an omission:
///
///  * `Expanded`, `Flexible`, `Stack`, `Positioned`, `ConstrainedBox` and
///    `LayoutBuilder` stay written as themselves. Flex and constraint topology
///    is structure — remove it and the screen stops laying out — so the
///    blueprint must honour it exactly and the application keeps stating it.
///  * A corner radius has no façade because it has no question. "This corner is
///    12dp" is Material's answer; M3 rounds at 8–12, Fluent at 4–8 and macOS at
///    5–6 and all three are right, and *nothing the application knows* picks
///    between them. A radius therefore does not become a rung — it is deleted
///    together with the hand-painted surface it decorates, when that surface
///    becomes its `SkinSurfaces` member. Minting a `Corner` vocabulary to
///    preserve today's radii would duplicate the surface taxonomy under a new
///    name, which `docs/SKIN-CONTRACT-MEMBERS.md` §10 names as the failure the
///    whole contract exists to prevent.
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The distance between two neighbours, stated as their relationship.
///
/// The mechanical replacement for a childless `SizedBox(width:)` or
/// `SizedBox(height:)` used as a gap. One type serves both axes: the rendered
/// gap reads the enclosing flex's direction from the render tree, so a
/// `BaseGap` in a [Row] is horizontal and the same `BaseGap` in a [Column] is
/// vertical, and a call site never restates an axis its parent already fixed.
///
/// Where a whole run is uniformly spaced, the gap belongs on the run rather
/// than between its children — `Flex.spacing` absorbs it — and this widget is
/// for the runs that are not uniform, which is most of them.
class BaseGap extends StatelessWidget {
  /// Puts [proximity]'s worth of distance between the two neighbours it sits
  /// between.
  const BaseGap(this.proximity, {super.key});

  /// How closely the two neighbours belong together.
  final Proximity proximity;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.layout.gap(inner, proximity);
      });
}

/// The breathing room a container owes its content.
///
/// The replacement for `Padding(padding: EdgeInsets.…)` and for the `padding:`
/// slot of a hand-painted `Container`. A `Container` that also decorates keeps
/// its decoration and hands its padding here — `Container` applies its padding
/// *inside* its decoration, so moving the padding to a child changes nothing
/// the user sees, and the decoration follows later, when the surface becomes
/// its `SkinSurfaces` member and takes the fill and the corner with it.
///
/// [x] and [y] override [all] per axis, mirroring `SkinLayout.inset` exactly
/// so that there is one shape for one idea. That per-axis pair is what lets a
/// dense row say "the ordinary reading distance across, barely set in down the
/// page" without either restating a number or picking a rung it does not mean.
///
/// There is deliberately no per-*side* form. `EdgeInsets.only(left:, top:)` is
/// nearly always a gap wearing a padding idiom — the space belongs *between*
/// two things rather than *inside* one — and it is restated as composition: the
/// neighbour above owns a [BaseGap], and the block below takes an inset. Four
/// per-side rungs would be the token bag returning under a neutral label.
class BaseInset extends StatelessWidget {
  /// Sets [child] in from its container's edge.
  const BaseInset({
    super.key,
    this.all = Inset.normal,
    this.x,
    this.y,
    required this.child,
  });

  /// The rung both axes take unless overridden.
  final Inset all;

  /// The horizontal rung, where it differs from [all].
  final Inset? x;

  /// The vertical rung, where it differs from [all].
  final Inset? y;

  /// The content being set in.
  final Widget child;

  @override
  Widget build(BuildContext context) => SkinScope.render(context, (
    Skin skin,
    BuildContext inner,
  ) {
    return skin.layout.inset(inner, ContentPort(child), all: all, x: x, y: y);
  });
}

/// A statement that two regions are about different things.
///
/// The replacement for `Divider` and `VerticalDivider`. The application says
/// that a division exists and how far in from the leading edge it starts; what
/// is drawn there — a rule, a hairline, extra space and nothing else — is the
/// skin's idiom.
class BaseSeparator extends StatelessWidget {
  /// Divides along [axis], starting [indent] in from the leading edge.
  const BaseSeparator({
    super.key,
    this.axis = Axis.horizontal,
    this.indent = Inset.none,
  });

  /// Which way the division runs. Horizontal separates rows, vertical
  /// separates columns.
  final Axis axis;

  /// How far in from the leading edge the division starts, for a division that
  /// belongs to indented content rather than to the whole width.
  final Inset indent;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.layout.separator(inner, axis: axis, indent: indent);
      });
}
