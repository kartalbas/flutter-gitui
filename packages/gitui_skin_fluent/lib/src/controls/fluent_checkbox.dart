import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import 'fluent_control_marks.dart';
import 'fluent_pressable.dart';

/// The Fluent answer to `SkinControls.checkbox`: IS THIS FACT TRUE - drawn
/// against the WinUI CheckBox, with no widget library underneath.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/inputs/checkbox.dart):
///
///  * a 20 epx box (:152) rounded at 6 (:360, `CheckboxThemeData.standard`);
///  * UNCHECKED: the input well - `ControlAltFillColorSecondary` at rest,
///    `Tertiary` hovered, `Quarternary` pressed, `Disabled` disabled -
///    behind a 1 epx `ControlStrongStrokeColorDefault` border that falls to
///    `Disabled` while pressed or disabled (:376-392);
///  * CHECKED and MIXED: the accent ladder - the same
///    `checkedInputColor` ramp the accent button dims through (rest
///    `defaultBrush`, hover `secondaryBrush`, press `tertiaryBrush`,
///    disabled `AccentFillColorDisabled`; buttons/theme.dart:355-360 via
///    filled_button.dart:100-110) - under a 12 epx mark in the on-accent
///    foreground (:184-186, 404-406);
///  * the mixed state is a horizontal bar, not a dimmer check, so a folder
///    partly selected never reads as a folder selected.
///
/// Operating a mixed control means "make it true" - the same resolution the
/// blueprint documents - and a checked one unchecks, so the cycle is
/// mixed -> true -> false -> true.
final class FluentCheckbox extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentCheckbox({super.key, required this.spec});

  /// What the application declared.
  final ToggleSpec spec;

  /// The box, 20 epx (checkbox.dart:152).
  static const double boxExtent = 20;

  /// The box corner, 6 epx (checkbox.dart:360).
  static const double cornerRadius = 6;

  /// The mark's glyph box, 12 epx (checkbox.dart:186).
  static const double markExtent = 12;

  /// Whether the user may flip it right now.
  bool get operable => spec.enabled && spec.onChanged != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: spec.value ?? false,
      mixed: spec.value == null,
      child: FluentPressable(
        onPressed: operable ? () => spec.onChanged!(spec.value != true) : null,
        semanticsLabel: spec.label,
        builder: (BuildContext context, Set<WidgetState> states) =>
            FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: FluentCheckboxBox(value: spec.value, states: states),
            ),
      ),
    );
  }
}

/// The checkbox's drawn box and mark for one value under one state set -
/// split from [FluentCheckbox] so the labelled row (`toggleRow`) can wear
/// the identical box inside its own pressable.
final class FluentCheckboxBox extends StatelessWidget {
  /// Draws the box for [value] under [states].
  const FluentCheckboxBox({
    super.key,
    required this.value,
    required this.states,
  });

  /// The fact: true, false, or mixed.
  final bool? value;

  /// The interaction states in force.
  final Set<WidgetState> states;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool marked = value != false;
    final bool disabled = states.contains(WidgetState.disabled);

    final Color fill;
    final Color stroke;
    if (marked) {
      // The accent ladder (checkbox.dart:365-374 via
      // ButtonThemeData.checkedInputColor -> filled_button.dart:100-110);
      // the border wears the same colour, so the box reads as one solid.
      fill = _checkedInputColor(theme, states);
      stroke = disabled ? res.controlStrongStrokeColorDisabled : fill;
    } else {
      // The input well (checkbox.dart:376-392).
      fill = disabled
          ? res.controlAltFillColorDisabled
          : states.contains(WidgetState.pressed)
          ? res.controlAltFillColorQuarternary
          : states.contains(WidgetState.hovered)
          ? res.controlAltFillColorTertiary
          : res.controlAltFillColorSecondary;
      stroke = disabled || states.contains(WidgetState.pressed)
          ? res.controlStrongStrokeColorDisabled
          : res.controlStrongStrokeColorDefault;
    }

    final Color markInk = disabled
        ? res.textOnAccentFillColorDisabled
        : res.textOnAccentFillColorPrimary;

    return AnimatedContainer(
      // The box answers at the container step on the standard curve, like
      // every other control container (buttons/base.dart:218-219).
      duration: FluentMotion.faster,
      curve: FluentMotion.curve,
      width: FluentCheckbox.boxExtent,
      height: FluentCheckbox.boxExtent,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(FluentCheckbox.cornerRadius),
        border: Border.all(color: stroke),
      ),
      child: Center(
        child: switch (value) {
          true => FluentCheckMark(
            color: markInk,
            size: FluentCheckbox.markExtent,
          ),
          null => FluentMixedMark(
            color: markInk,
            size: FluentCheckbox.markExtent,
          ),
          false => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The accent fill a checked input wears per state: the ramp
/// `ButtonThemeData.checkedInputColor` resolves (buttons/theme.dart:355-360,
/// delegating to filled_button.dart:100-110). Shared by the checkbox, the
/// switch, the radio and the checked toggle button, exactly as the
/// reference shares it.
Color _checkedInputColor(FluentThemeData theme, Set<WidgetState> states) {
  if (states.contains(WidgetState.disabled)) {
    return theme.resources.accentFillColorDisabled;
  }
  if (states.contains(WidgetState.pressed)) {
    return theme.accent.tertiaryBrushFor(theme.brightness);
  }
  if (states.contains(WidgetState.hovered)) {
    return theme.accent.secondaryBrushFor(theme.brightness);
  }
  return theme.accent.defaultBrushFor(theme.brightness);
}

/// The one place other Fluent controls borrow the checked-input ramp from,
/// so the ramp cannot fork per control.
Color fluentCheckedInputColor(FluentThemeData theme, Set<WidgetState> states) =>
    _checkedInputColor(theme, states);
