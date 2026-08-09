import 'package:flutter/widgets.dart';

import 'fluent_geometry.dart';
import 'fluent_resources.dart';
import 'fluent_theme.dart';

/// Fluent's high-visibility focus rectangle: TWO strokes, an outer and an
/// inner, drawn OUTSIDE the control they mark.
///
/// Two strokes is the whole design. The outer stroke is dark on a light
/// ground and light on a dark one; the inner stroke is always its opposite,
/// so whichever way the control underneath is filled, one of the two strokes
/// contrasts with it. A single-stroke reimplementation is exactly the kind
/// of "close enough" that stops being legible over an accent fill.
///
/// Structure and metrics from the reference: fluent_ui@4.16.1
/// lib/src/controls/utils/focus.dart -
///  * two nested decorations, outer painted first (:69-87);
///  * outer stroke 2 epx `focusStrokeColorOuter`, inner 1 epx
///    `focusStrokeColorInner`, corner radius 6 (:210-222);
///  * rendered outside the child by the sum of both stroke widths, over a
///    passthrough Stack, ignoring pointers (:95-111).
///
/// One divergence from the checkout, in the specification's favour. The
/// reference paints both strokes against the SAME rectangle edge (both
/// decorations inside-aligned on one box, focus.dart:76-84), so its inner
/// colour overpaints the outermost pixel and ends up outside the outer
/// stroke. The published order is the reverse - "a 2px outer border and a
/// 1px inner border", the inner stroke between the outer one and the
/// element (WinUI "Focus visuals",
/// https://learn.microsoft.com/en-us/windows/apps/design/input/guidelines-for-visualfeedback#focus-visuals) -
/// so the inner decoration here is inset by the outer stroke's width.
final class FluentFocusRing extends StatelessWidget {
  /// Wraps [child] with the rectangle, shown only while [focused].
  const FluentFocusRing({
    super.key,
    required this.focused,
    required this.child,
  });

  /// Whether the rectangle is visible. The decision of WHEN - keyboard
  /// focus, never pointer focus - belongs to the pressable driving this.
  final bool focused;

  /// The control the rectangle marks.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentResources resources = FluentTheme.of(context).resources;
    final BorderRadius corner = BorderRadius.circular(
      FluentGeometry.focusCornerRadius,
    );
    // Concentric with the outer rectangle: a corner inset by the outer
    // stroke's width keeps the same centre, so the inner radius is the outer
    // one shrunk by that width (6 - 2 = 4, landing back on the control
    // corner).
    final BorderRadius innerCorner = BorderRadius.circular(
      FluentGeometry.focusCornerRadius - FluentGeometry.focusStrokeOuterWidth,
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        PositionedDirectional(
          start: -FluentGeometry.focusRingOffset,
          end: -FluentGeometry.focusRingOffset,
          top: -FluentGeometry.focusRingOffset,
          bottom: -FluentGeometry.focusRingOffset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: corner,
                  side: focused
                      ? BorderSide(
                          width: FluentGeometry.focusStrokeOuterWidth,
                          color: resources.focusStrokeColorOuter,
                        )
                      : BorderSide.none,
                ),
              ),
              // Inset by the outer width so the inner stroke sits BETWEEN
              // the outer stroke and the control - the published nesting;
              // see the class doc for the divergence from the checkout.
              child: Padding(
                padding: const EdgeInsets.all(
                  FluentGeometry.focusStrokeOuterWidth,
                ),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: innerCorner,
                      side: focused
                          ? BorderSide(
                              width: FluentGeometry.focusStrokeInnerWidth,
                              color: resources.focusStrokeColorInner,
                            )
                          : BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
