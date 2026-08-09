/// The Fluent progress pair: the WinUI ProgressBar and ProgressRing, drawn.
///
/// Metrics and inks from the reference (fluent_ui@4.16.1
/// lib/src/controls/surfaces/progress_indicators.dart):
///
///  * both indicators stroke at 4.5 epx (:56, :365);
///  * the bar wants at least 130 epx of run (:7, :146) and the ring at
///    least 36 (:6);
///  * the active run is the accent brush and the rest of the range is the
///    theme's inactive background - `#d6d6d6` light / `#292929` dark
///    (styles/theme.dart:452-454), read at progress_indicators.dart:161-165;
///  * a null value is genuinely indeterminate in BOTH forms - Fluent is not
///    the language that cannot draw one - as a run that sweeps its track
///    (:99-140) and an arc that orbits (:430-480).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../fluent_theme.dart';

/// The bar. `SkinControls.progress` at `ProgressExtent.inline`.
final class FluentProgressBar extends StatefulWidget {
  /// Draws the bar at [fraction], or indeterminate when null.
  const FluentProgressBar({super.key, required this.fraction});

  /// How far along, 0..1, or null when the end is unknowable.
  final double? fraction;

  /// Stroke thickness (progress_indicators.dart:56).
  static const double strokeWidth = 4.5;

  /// Minimum run (progress_indicators.dart:7).
  static const double minWidth = 130;

  @override
  State<FluentProgressBar> createState() => _FluentProgressBarState();
}

class _FluentProgressBarState extends State<FluentProgressBar>
    with SingleTickerProviderStateMixin {
  /// The indeterminate sweep's cycle: 3 s (progress_indicators.dart:108).
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.fraction == null) _cycle.repeat();
  }

  @override
  void didUpdateWidget(FluentProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction == null && !_cycle.isAnimating) {
      _cycle.repeat();
    } else if (widget.fraction != null && _cycle.isAnimating) {
      _cycle.stop();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Semantics(
      value: widget.fraction == null
          ? null
          : '${(widget.fraction!.clamp(0, 1) * 100).round()}%',
      child: Container(
        height: FluentProgressBar.strokeWidth,
        constraints: const BoxConstraints(minWidth: FluentProgressBar.minWidth),
        child: AnimatedBuilder(
          animation: _cycle,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            painter: _BarPainter(
              fraction: widget.fraction?.clamp(0, 1).toDouble(),
              cycle: _cycle.value,
              activeInk: theme.accent.defaultBrushFor(theme.brightness),
              restInk: _inactiveBackground(theme),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring. `SkinControls.progress` at `ProgressExtent.block`.
final class FluentProgressRing extends StatefulWidget {
  /// Draws the ring at [fraction], or indeterminate when null.
  const FluentProgressRing({super.key, required this.fraction});

  /// How far along, 0..1, or null when the end is unknowable.
  final double? fraction;

  /// Stroke thickness (progress_indicators.dart:365).
  static const double strokeWidth = 4.5;

  /// The ring's diameter (progress_indicators.dart:6, the minimum size).
  static const double diameter = 36;

  @override
  State<FluentProgressRing> createState() => _FluentProgressRingState();
}

class _FluentProgressRingState extends State<FluentProgressRing>
    with SingleTickerProviderStateMixin {
  /// The orbit cycle. The reference runs its ring on a 2 s curve set
  /// (progress_indicators.dart:430-445).
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    if (widget.fraction == null) _cycle.repeat();
  }

  @override
  void didUpdateWidget(FluentProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction == null && !_cycle.isAnimating) {
      _cycle.repeat();
    } else if (widget.fraction != null && _cycle.isAnimating) {
      _cycle.stop();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Semantics(
      value: widget.fraction == null
          ? null
          : '${(widget.fraction!.clamp(0, 1) * 100).round()}%',
      child: SizedBox.square(
        dimension: FluentProgressRing.diameter,
        child: AnimatedBuilder(
          animation: _cycle,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            painter: _RingPainter(
              fraction: widget.fraction?.clamp(0, 1).toDouble(),
              cycle: _cycle.value,
              activeInk: theme.accent.defaultBrushFor(theme.brightness),
              restInk: _inactiveBackground(theme),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rest-of-range ink: `FluentThemeData.inactiveBackgroundColor`
/// (styles/theme.dart:452-454).
Color _inactiveBackground(FluentThemeData theme) =>
    theme.brightness == Brightness.light
    ? const Color(0xFFd6d6d6)
    : const Color(0xFF292929);

/// Paints the bar: full rest track, accent run - determinate from zero,
/// indeterminate sweeping with the cycle.
final class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.cycle,
    required this.activeInk,
    required this.restInk,
  });

  final double? fraction;
  final double cycle;
  final Color activeInk;
  final Color restInk;

  @override
  void paint(Canvas canvas, Size size) {
    final Radius cap = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, size.width, size.height, cap),
      Paint()..color = restInk,
    );
    final Paint active = Paint()..color = activeInk;
    if (fraction != null) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, size.width * fraction!, size.height, cap),
        active,
      );
      return;
    }
    // The indeterminate run: a third of the track sweeping left to right,
    // the reference's simplified single-run cycle
    // (progress_indicators.dart:99-140).
    final double runWidth = size.width / 3;
    final double travel = (size.width + runWidth) * cycle;
    final double left = (travel - runWidth).clamp(0, size.width);
    final double right = travel.clamp(0, size.width);
    if (right > left) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, 0, right, size.height, cap),
        active,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.cycle != cycle ||
      oldDelegate.activeInk != activeInk ||
      oldDelegate.restInk != restInk;
}

/// Paints the ring: rest circle, accent arc from the top - determinate by
/// fraction, indeterminate orbiting with the cycle.
final class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.cycle,
    required this.activeInk,
    required this.restInk,
  });

  final double? fraction;
  final double cycle;
  final Color activeInk;
  final Color restInk;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect arcBounds = bounds.deflate(FluentProgressRing.strokeWidth / 2);
    final Paint rest = Paint()
      ..color = restInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = FluentProgressRing.strokeWidth;
    final Paint active = Paint()
      ..color = activeInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = FluentProgressRing.strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcBounds, 0, math.pi * 2, false, rest);
    if (fraction != null) {
      canvas.drawArc(
        arcBounds,
        -math.pi / 2,
        math.pi * 2 * fraction!,
        false,
        active,
      );
      return;
    }
    // The orbiting arc: a quarter-turn head chasing around the ring.
    canvas.drawArc(
      arcBounds,
      -math.pi / 2 + math.pi * 2 * cycle,
      math.pi / 2,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.cycle != cycle ||
      oldDelegate.activeInk != activeInk ||
      oldDelegate.restInk != restInk;
}
