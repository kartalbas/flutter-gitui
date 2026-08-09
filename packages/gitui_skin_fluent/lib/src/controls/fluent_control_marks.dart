/// The marks that are CONTROL ANATOMY in Fluent, drawn as geometry.
///
/// Two different questions hide under "icon", and this file answers only the
/// first. A checkbox's check, the mixed-state bar and a combo box's chevron
/// are parts of a control the way a switch's knob is - WinUI renders them
/// from `Segoe Fluent Icons`, but their size, stroke and placement are fixed
/// by the control's own template, and a Fluent control without them is not a
/// sparser Fluent control, it is a broken one. So they are traced here as
/// stroked paths, each to the metric the reference gives it, exactly as the
/// slider draws its own thumb.
///
/// The second question - which mark stands for an application idea
/// (`IconRole`, 155 members) - is NOT answered here and must not be: that is
/// the Fluent glyph-table decision `FluentButton`'s doc already registers as
/// pending, a vocabulary of its own with its own provenance burden. Tracing
/// 155 glyphs by hand would be inventing an icon set; tracing three template
/// marks is finishing three controls.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The check mark inside a checked checkbox.
///
/// WinUI draws the `CheckMark` glyph (Segoe Fluent Icons U+E73E) at 12 epx
/// inside the 20 epx box (fluent_ui@4.16.1
/// lib/src/controls/inputs/checkbox.dart:184-186). The path here is that
/// glyph's two strokes - the short descending arm meeting the long ascending
/// one at the baseline third - drawn at the same 12 epx bounding box.
final class FluentCheckMark extends StatelessWidget {
  /// Draws the mark in [color] inside a box of [size] logical pixels.
  const FluentCheckMark({super.key, required this.color, this.size = 12});

  /// The ink of the mark: on-accent white over the checked fill.
  final Color color;

  /// The glyph box, 12 epx in the reference (checkbox.dart:186).
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StrokePathPainter(
      color: color,
      // A 12 epx glyph's stroke reads at about an epx and a half; heavier
      // and the mark clogs the 20 epx box, lighter and it breaks up at
      // 100% scaling.
      strokeWidth: size / 8,
      points: const <Offset>[
        Offset(0.08, 0.52),
        Offset(0.38, 0.82),
        Offset(0.92, 0.2),
      ],
    ),
  );
}

/// The bar inside a mixed-state checkbox.
///
/// WinUI's indeterminate checkbox carries a short horizontal bar centred in
/// the box (the `CheckboxIndeterminateGlyph`); the reference renders it
/// through the same 12 epx glyph slot as the check
/// (fluent_ui@4.16.1 lib/src/controls/inputs/checkbox.dart:178-196).
final class FluentMixedMark extends StatelessWidget {
  /// Draws the bar in [color] inside a box of [size] logical pixels.
  const FluentMixedMark({super.key, required this.color, this.size = 12});

  /// The ink of the bar.
  final Color color;

  /// The glyph box, shared with [FluentCheckMark].
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StrokePathPainter(
      color: color,
      strokeWidth: size / 8,
      points: const <Offset>[Offset(0.15, 0.5), Offset(0.85, 0.5)],
    ),
  );
}

/// The chevron a closed combo box points downward.
///
/// WinUI's ComboBox closes on a `ChevronDown` glyph (fluent_ui@4.16.1
/// lib/src/controls/form/combo_box.dart:978, `WindowsIcons.chevron_down`),
/// drawn in the 12 epx compact glyph slot the language uses for inline marks
/// (the breadcrumb overflow draws its chevron at 12,
/// navigation/breadcrumb_bar.dart:195).
final class FluentChevron extends StatelessWidget {
  /// Draws the chevron in [color], rotated [turns] quarter-turns from
  /// pointing down.
  const FluentChevron({
    super.key,
    required this.color,
    this.size = 12,
    this.turns = 0,
  });

  /// The ink of the chevron.
  final Color color;

  /// The glyph box.
  final double size;

  /// Quarter-turns anticlockwise from the resting downward point: 2 flips
  /// it upward for an open combo box.
  final int turns;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: turns,
    child: CustomPaint(
      size: Size.square(size),
      painter: _StrokePathPainter(
        color: color,
        strokeWidth: size / 10,
        points: const <Offset>[
          Offset(0.15, 0.35),
          Offset(0.5, 0.68),
          Offset(0.85, 0.35),
        ],
      ),
    ),
  );
}

/// A polyline in unit coordinates, stroked with round caps and joins - the
/// stroke discipline Segoe's marks share.
final class _StrokePathPainter extends CustomPainter {
  const _StrokePathPainter({
    required this.color,
    required this.strokeWidth,
    required this.points,
  });

  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final Path path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StrokePathPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.points != points;
}
