import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import 'fluent_checkbox.dart';
import 'fluent_pressable.dart';

/// The Fluent answer to `SkinControls.toggle`: IS THIS SETTING ON - drawn
/// against the WinUI ToggleSwitch.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/inputs/toggle_switch.dart):
///
///  * a 40 x 20 stadium track (:232-235, radius 100 at :434-441);
///  * OFF: the input well ladder (`ControlAltFillColorSecondary` /
///    `Tertiary` / `Quarternary` / `Disabled`) behind a 1 epx
///    `ControlStrongFillColorDefault` border (:452-467);
///  * ON: the checked-input accent ramp as both fill and border (:445-451),
///    shared with the checkbox through `fluentCheckedInputColor`;
///  * the knob is a circle in `TextOnAccentFillColorPrimary` when on and
///    `TextFillColorSecondary` when off (:473-486), resting at 12 epx and
///    growing 2 on hover and 5 more while pressed (:305-316) - the stretch
///    toward the pointer that makes a WinUI switch feel latched rather than
///    tapped;
///  * the knob slides between the track ends on the fast step (:229-247).
///
/// A switch is two-state by construction: the mixed value renders as "not
/// on", exactly as the Material skin resolves it, because the mixed state
/// belongs to the checkbox - the control that can draw it.
final class FluentToggleSwitch extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentToggleSwitch({super.key, required this.spec});

  /// What the application declared.
  final ToggleSpec spec;

  /// Track width, 40 epx (toggle_switch.dart:234).
  static const double trackWidth = 40;

  /// Track height, 20 epx (toggle_switch.dart:233).
  static const double trackHeight = 20;

  /// The knob's resting diameter: the track height minus the 3 epx resting
  /// margin on each side (toggle_switch.dart:305-311, margin 2 + factor 1).
  static const double knobRest = 14;

  /// Whether the user may flip it right now.
  bool get operable => spec.enabled && spec.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final bool on = spec.value ?? false;
    return Semantics(
      toggled: on,
      child: FluentPressable(
        onPressed: operable ? () => spec.onChanged!(!on) : null,
        semanticsLabel: spec.label,
        builder: (BuildContext context, Set<WidgetState> states) =>
            FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: FluentToggleSwitchTrack(on: on, states: states),
            ),
      ),
    );
  }
}

/// The switch's drawn track and knob for one value under one state set -
/// split out so the labelled row can wear the identical track.
final class FluentToggleSwitchTrack extends StatelessWidget {
  /// Draws the track for [on] under [states].
  const FluentToggleSwitchTrack({
    super.key,
    required this.on,
    required this.states,
  });

  /// Whether the setting is on.
  final bool on;

  /// The interaction states in force.
  final Set<WidgetState> states;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool disabled = states.contains(WidgetState.disabled);
    final bool hovered = states.contains(WidgetState.hovered);
    final bool pressed = states.contains(WidgetState.pressed);

    final Color fill;
    final Color stroke;
    if (on) {
      // toggle_switch.dart:445-451.
      fill = fluentCheckedInputColor(theme, states);
      stroke = fill;
    } else {
      // toggle_switch.dart:452-467.
      fill = disabled
          ? res.controlAltFillColorDisabled
          : pressed
          ? res.controlAltFillColorQuarternary
          : hovered
          ? res.controlAltFillColorTertiary
          : res.controlAltFillColorSecondary;
      stroke = disabled
          ? res.controlStrongFillColorDisabled
          : res.controlStrongFillColorDefault;
    }

    // The knob's inks (toggle_switch.dart:473-486).
    final Color knobInk = on
        ? (disabled
              ? res.textOnAccentFillColorDisabled
              : res.textOnAccentFillColorPrimary)
        : (disabled ? res.textFillColorDisabled : res.textFillColorSecondary);

    // The knob's stretch (toggle_switch.dart:305-316): margin 3 at rest and
    // 2 while hovered; width grows 2 hovered and 5 more pressed.
    final double margin = hovered && !disabled ? 2 : 3;
    final double knobHeight = FluentToggleSwitch.trackHeight - margin * 2;
    final double knobWidth =
        FluentToggleSwitch.knobRest +
        (hovered && !disabled ? 2 : 0) +
        (pressed && !disabled ? 5 : 0);

    return AnimatedContainer(
      // The knob slides on the fast step (toggle_switch.dart:229-231 with
      // fasterAnimationDuration... the reference feeds its container the
      // faster step; the standard curve throughout).
      duration: FluentMotion.faster,
      curve: FluentMotion.curve,
      width: FluentToggleSwitch.trackWidth,
      height: FluentToggleSwitch.trackHeight,
      alignment: on
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      padding: EdgeInsetsDirectional.symmetric(horizontal: margin),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(FluentGeometry.stadiumRadius),
        border: Border.all(color: stroke),
      ),
      child: AnimatedContainer(
        duration: FluentMotion.faster,
        curve: FluentMotion.curve,
        width: knobWidth,
        height: knobHeight,
        decoration: BoxDecoration(
          color: knobInk,
          borderRadius: BorderRadius.circular(FluentGeometry.stadiumRadius),
        ),
      ),
    );
  }
}
