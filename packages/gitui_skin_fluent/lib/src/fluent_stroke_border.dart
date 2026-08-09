import 'package:flutter/widgets.dart';

import 'fluent_geometry.dart';

/// The one-stroke outline a Fluent control wears, in either of its two
/// lives: a vertical-gradient "elevation stroke" at rest and hover, or a
/// plain solid stroke when pressed or disabled.
///
/// The gradient is the signature: the bottom run of a resting control's
/// outline is darker than the rest, which is what makes the control read as
/// standing a hair proud of the surface - and it FLATTENS to a solid stroke
/// the moment the control is pressed, which is half of why a Fluent press
/// feels like the control being pushed in. The reference draws this with its
/// own `RoundedRectangleGradientBorder`
/// (fluent_ui@4.16.1 lib/src/controls/utils/
/// rounded_rectangle_gradient_border.dart:141-153, a `drawDRRect` filled
/// with the gradient's shader); this class is that knowledge rewritten, not
/// that code vendored: one width, inside-aligned, gradient or solid.
final class FluentStrokeBorder extends ShapeBorder {
  /// A stroke painted with [gradient].
  const FluentStrokeBorder.gradient({
    required Gradient this.gradient,
    required this.borderRadius,
  }) : color = null;

  /// A stroke painted with one flat [color].
  const FluentStrokeBorder.solid({
    required Color this.color,
    required this.borderRadius,
  }) : gradient = null;

  /// The vertical ramp of the elevation stroke, or null when [color] paints.
  final Gradient? gradient;

  /// The flat stroke of the pressed and disabled states, or null when
  /// [gradient] paints.
  final Color? color;

  /// The corner this outline follows.
  final BorderRadius borderRadius;

  /// One physical stroke, always (FluentGeometry.strokeWidth provenance).
  double get width => FluentGeometry.strokeWidth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsetsDirectional.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect).deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect));

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(borderRadius.toRRect(rect), paint);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final RRect outer = borderRadius.toRRect(rect);
    final RRect inner = outer.deflate(width);
    final Paint paint = Paint();
    final Gradient? gradient = this.gradient;
    if (gradient != null) {
      // The ring between the outer and inner rounded rectangles, filled with
      // the gradient's shader - the reference's own drawing call
      // (rounded_rectangle_gradient_border.dart:146-151).
      paint.shader = gradient.createShader(rect, textDirection: textDirection);
    } else {
      final Color? color = this.color;
      if (color == null || color.a == 0) {
        return;
      }
      paint.color = color;
    }
    canvas.drawDRRect(outer, inner, paint);
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) {
    return other is FluentStrokeBorder &&
        other.gradient == gradient &&
        other.color == color &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(gradient, color, borderRadius);
}
