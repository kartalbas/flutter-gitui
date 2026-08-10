import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_ink.dart';
import '../fluent_theme.dart';
import 'fluent_surface_parts.dart';

/// The Fluent answer to `surfaces.commitGraphRow`: the lanes, edges and
/// dot of one commit row, painted by this skin.
///
/// No design language publishes a commit graph, so the drawing is this
/// skin's own and its NUMBERS are application heritage rather than
/// invention: the 12 epx lane, 4 epx dot, 2 epx stroke and eight-lane cap
/// that sat beside the application's own `commit_graph_painter` before
/// the member existed (`FluentSurfaceMetrics.graphLaneWidth` and
/// friends). What is Fluent about it is the ink: every lane takes its
/// colour from this skin's series - the reference's own accent families
/// resolved per brightness (`FluentInk.series`).
///
/// It FILLS the box it is given rather than sizing itself, so each row's
/// lane segments meet its neighbours' edge to edge - the reservation that
/// makes room beside the content is [FluentCommitGraphGutter]'s.
final class FluentCommitGraphRow extends StatelessWidget {
  /// Draws [spec]'s graph.
  const FluentCommitGraphRow({super.key, required this.spec});

  /// What the application declared.
  final GraphRowSpec spec;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _FluentGraphPainter(
        spec: spec,
        brightness: FluentTheme.of(context).brightness,
      ),
    ),
  );
}

/// The room one commit row reserves beside its content for the graph:
/// one lane's width per lane in play, capped at the same eight lanes the
/// painter draws - asked of the same constants, so the reservation and
/// the drawing cannot drift apart inside this skin. A widget, never a
/// width: the application mounts room.
final class FluentCommitGraphGutter extends StatelessWidget {
  /// Reserves room for [spec].
  const FluentCommitGraphGutter({super.key, required this.spec});

  /// What the application declared.
  final GraphGutterSpec spec;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _FluentGraphPainter.gutterWidthFor(spec.laneCount));
}

final class _FluentGraphPainter extends CustomPainter {
  const _FluentGraphPainter({required this.spec, required this.brightness});

  final GraphRowSpec spec;
  final Brightness brightness;

  /// The gutter's width for [laneCount] lanes: one lane each, at least
  /// one, at most the cap.
  static double gutterWidthFor(int laneCount) =>
      FluentSurfaceMetrics.graphLaneWidth *
      laneCount.clamp(1, FluentSurfaceMetrics.graphLaneCap);

  /// The x of a lane's centre, clamped into the capped gutter so a
  /// pathological window crowds its outermost lanes rather than the
  /// subject text.
  static double _laneX(int lane) =>
      (math.min(lane, FluentSurfaceMetrics.graphLaneCap - 1) + 0.5) *
      FluentSurfaceMetrics.graphLaneWidth;

  Paint _stroke(int toneIndex) => Paint()
    ..color = FluentInk.series(brightness, toneIndex)
    ..style = PaintingStyle.stroke
    ..strokeWidth = FluentSurfaceMetrics.graphStrokeWidth
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double middle = size.height / 2;
    final double dotX = _laneX(spec.lane);

    // Lanes running straight through, behind everything else.
    for (final GraphEdgeSpec edge in spec.passing) {
      final double x = _laneX(edge.lane);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        _stroke(edge.toneIndex),
      );
    }
    // Edges arriving from the row above, bending into the dot.
    for (final GraphEdgeSpec edge in spec.incoming) {
      final double x = _laneX(edge.lane);
      final Path path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x, middle, dotX, middle);
      canvas.drawPath(path, _stroke(edge.toneIndex));
    }
    // Edges leaving towards the row below.
    for (final GraphEdgeSpec edge in spec.outgoing) {
      final double x = _laneX(edge.lane);
      final Path path = Path()
        ..moveTo(dotX, middle)
        ..quadraticBezierTo(x, middle, x, size.height);
      canvas.drawPath(path, _stroke(edge.toneIndex));
    }

    final Color dotColor = FluentInk.series(brightness, spec.toneIndex);
    final Offset dotCentre = Offset(dotX, middle);
    if (spec.isMerge) {
      // A merge joins several parents: its dot is a ring rather than a
      // fill, so the joins read through it - this skin's own mark.
      canvas.drawCircle(
        dotCentre,
        FluentSurfaceMetrics.graphDotRadius,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = FluentSurfaceMetrics.graphStrokeWidth,
      );
    } else {
      canvas.drawCircle(
        dotCentre,
        FluentSurfaceMetrics.graphDotRadius,
        Paint()..color = dotColor,
      );
    }
    if (spec.isCurrent) {
      // HEAD's halo: a second ring one stroke outside the dot, so the
      // one commit the eye must find in a thousand-row window carries
      // its own mark.
      canvas.drawCircle(
        dotCentre,
        FluentSurfaceMetrics.graphDotRadius +
            FluentSurfaceMetrics.graphStrokeWidth,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = FluentSurfaceMetrics.graphStrokeWidth / 2,
      );
    }
  }

  /// The contract declares value equality on every graph spec precisely
  /// so this comparison is cheap and cannot rot when the spec grows a
  /// field.
  @override
  bool shouldRepaint(_FluentGraphPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.brightness != brightness;
}
