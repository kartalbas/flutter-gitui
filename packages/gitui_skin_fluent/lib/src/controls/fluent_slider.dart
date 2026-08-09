import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import 'fluent_checkbox.dart';

/// The Fluent answer to `SkinControls.slider`: WHERE ALONG THIS RANGE -
/// drawn against the WinUI Slider.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/inputs/slider.dart, `SliderThemeData.standard`
/// :724-754):
///
///  * a 3.75 epx stadium track (:750): the run left of the thumb filled
///    with the checked-input accent ramp (:729-731), the run right with
///    `ControlStrongFillColorDefault`, `Disabled` when disabled (:732-738);
///  * the thumb is a 10 epx-radius ball (:363) in
///    `ControlSolidFillColorDefault` (:362) around an accent core whose
///    share of the ball BREATHES with the pointer - 0.5 at rest, 0.66
///    hovered, 0.45 pressed (:741-747). The core growing toward the hover
///    and shrinking under the press is the WinUI slider's whole feel;
///  * `divisions` quantises the value rather than drawing ticks, exactly as
///    the other two skins treat it: the fact is that the value is discrete.
///
/// Keyboard: the slider is one Tab stop and the arrow keys step it - a
/// division when the value has divisions, a tenth of the range otherwise,
/// the same skin-chosen step the blueprint records for the same reason. The
/// focus rectangle is the language's own, drawn by [FluentFocusRing] under
/// the pressable rules (keyboard only).
final class FluentSlider extends StatefulWidget {
  /// Draws [spec] in Fluent.
  const FluentSlider({super.key, required this.spec});

  /// What the application declared.
  final SliderSpec spec;

  /// Track thickness (slider.dart:750).
  static const double trackHeight = 3.75;

  /// Thumb ball radius (slider.dart:363).
  static const double thumbRadius = 10;

  @override
  State<FluentSlider> createState() => _FluentSliderState();
}

class _FluentSliderState extends State<FluentSlider> {
  bool _hovering = false;
  bool _pressing = false;
  bool _showFocus = false;

  SliderSpec get spec => widget.spec;

  bool get _operable => spec.enabled && spec.onChanged != null;

  double get _span => spec.max - spec.min;

  /// One keyboard step; never zero, so the arithmetic cannot stall.
  double get _step {
    final int divisions = (spec.divisions ?? 0) > 0 ? spec.divisions! : 10;
    final double step = _span / divisions;
    return step > 0 ? step : 1;
  }

  void _report(double value, {required bool ended}) {
    final double clamped = value.clamp(spec.min, spec.max);
    final double snapped = (spec.divisions ?? 0) > 0
        ? spec.min + ((clamped - spec.min) / _step).round() * _step
        : clamped;
    spec.onChanged?.call(snapped);
    if (ended) spec.onChangeEnd?.call(snapped);
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final double fraction = _span <= 0
        ? 0
        : ((spec.value - spec.min) / _span).clamp(0, 1).toDouble();

    final Set<WidgetState> states = <WidgetState>{
      if (!_operable) WidgetState.disabled,
      if (_operable && _pressing) WidgetState.pressed,
      if (_operable && _hovering) WidgetState.hovered,
    };

    final Color activeInk = fluentCheckedInputColor(theme, states);
    final Color restInk = _operable
        ? res.controlStrongFillColorDefault
        : res.controlStrongFillColorDisabled;

    // The accent core's share of the thumb ball (slider.dart:741-747).
    final double innerFactor = !_operable
        ? 0.5
        : _pressing
        ? 0.45
        : _hovering
        ? 0.66
        : 0.5;

    return Semantics(
      slider: true,
      value: spec.valueLabel ?? '${spec.value}',
      enabled: _operable,
      child: FocusableActionDetector(
        enabled: _operable,
        onShowFocusHighlight: (bool value) =>
            setState(() => _showFocus = value),
        onShowHoverHighlight: (bool value) => setState(() => _hovering = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
        },
        actions: <Type, Action<Intent>>{
          _NudgeIntent: CallbackAction<_NudgeIntent>(
            onInvoke: (_NudgeIntent intent) {
              _report(spec.value + intent.direction * _step, ended: true);
              return null;
            },
          ),
        },
        child: FluentFocusRing(
          focused: _showFocus,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 200;
              double valueAt(Offset local) =>
                  spec.min +
                  _span *
                      ((local.dx - FluentSlider.thumbRadius) /
                              (width - FluentSlider.thumbRadius * 2))
                          .clamp(0, 1);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _operable
                    ? (DragStartDetails details) {
                        setState(() => _pressing = true);
                        _report(valueAt(details.localPosition), ended: false);
                      }
                    : null,
                onHorizontalDragUpdate: _operable
                    ? (DragUpdateDetails details) =>
                          _report(valueAt(details.localPosition), ended: false)
                    : null,
                onHorizontalDragEnd: _operable
                    ? (DragEndDetails details) {
                        setState(() => _pressing = false);
                        _report(spec.value, ended: true);
                      }
                    : null,
                onTapUp: _operable
                    ? (TapUpDetails details) =>
                          _report(valueAt(details.localPosition), ended: true)
                    : null,
                child: SizedBox(
                  width: width,
                  height: FluentSlider.thumbRadius * 2 + 2,
                  child: CustomPaint(
                    painter: _SliderPainter(
                      fraction: fraction,
                      activeInk: activeInk,
                      restInk: restInk,
                      ballInk: res.controlSolidFillColorDefault,
                      innerFactor: innerFactor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One arrow-key step in either direction.
final class _NudgeIntent extends Intent {
  const _NudgeIntent(this.direction);

  /// -1 toward `min`, +1 toward `max`.
  final int direction;
}

/// Paints the track and the breathing thumb.
final class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.fraction,
    required this.activeInk,
    required this.restInk,
    required this.ballInk,
    required this.innerFactor,
  });

  final double fraction;
  final Color activeInk;
  final Color restInk;
  final Color ballInk;
  final double innerFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double usable = size.width - FluentSlider.thumbRadius * 2;
    final double thumbX = FluentSlider.thumbRadius + usable * fraction;
    final Radius cap = Radius.circular(FluentSlider.trackHeight);

    // The rest of the range, right of the thumb.
    canvas.drawRRect(
      RRect.fromLTRBR(
        thumbX,
        centerY - FluentSlider.trackHeight / 2,
        size.width,
        centerY + FluentSlider.trackHeight / 2,
        cap,
      ),
      Paint()..color = restInk,
    );
    // The travelled run, left of the thumb, in the accent.
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        centerY - FluentSlider.trackHeight / 2,
        thumbX,
        centerY + FluentSlider.trackHeight / 2,
        cap,
      ),
      Paint()..color = activeInk,
    );
    // The thumb: solid ball, accent core at the breathing share.
    final Offset thumb = Offset(thumbX, centerY);
    canvas.drawCircle(
      thumb,
      FluentSlider.thumbRadius,
      Paint()..color = ballInk,
    );
    canvas.drawCircle(
      thumb,
      FluentSlider.thumbRadius * innerFactor,
      Paint()..color = activeInk,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.activeInk != activeInk ||
      oldDelegate.restInk != restInk ||
      oldDelegate.ballInk != ballInk ||
      oldDelegate.innerFactor != innerFactor;
}
