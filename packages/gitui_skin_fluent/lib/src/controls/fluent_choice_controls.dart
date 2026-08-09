/// The Fluent choosing controls: `choiceGroup`, `filterToggle` and
/// `dropdown`.
///
/// Fluent answers "which one of these few" with a RADIO GROUP - the
/// decomposition the contract's own doc records for this member - and "is
/// this condition on" with a ToggleButton, WinUI's checked button. "Which
/// one of these" is the ComboBox. Each control cites its reference anatomy
/// at the site.
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_stroke_border.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_checkbox.dart';
import 'fluent_control_marks.dart';
import 'fluent_pressable.dart';

/// The Fluent answer to `SkinControls.choiceGroup`: a WinUI radio group.
///
/// Radio anatomy from the reference (fluent_ui@4.16.1
/// lib/src/controls/inputs/radio_button.dart):
///
///  * a 20 epx circle (:174-175) beside its words at a 6 epx gap (:196);
///  * UNCHECKED: the input well ladder behind a ring that fattens from
///    1 epx to 4.5 while pressed, tinting to the accent (:334-352) - the
///    ring closing toward the centre is how a WinUI radio takes a press;
///  * CHECKED: an accent ring around the on-accent core, 5 epx at rest
///    RELAXING to 3.4 while hovered (:320-333) - hover breathes the core
///    larger, which is the radio's counterpart of the switch knob's
///    stretch.
///
/// The group is one row of radio-and-label pressables; `tooltip` per option
/// is announced until the overlay facet lands.
final class FluentChoiceGroup<T> extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentChoiceGroup({super.key, required this.spec});

  /// What the application declared.
  final ChoiceGroupSpec<T> spec;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: spec.label,
      container: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final ChoiceOption<T> option in spec.options)
            _RadioOption<T>(
              option: option,
              selected: option.value == spec.selected,
              onSelected: option.enabled
                  ? () => spec.onSelected(option.value)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// One radio with its words.
final class _RadioOption<T> extends StatelessWidget {
  const _RadioOption({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final ChoiceOption<T> option;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      tooltip: option.tooltip,
      child: FluentPressable(
        onPressed: onSelected,
        semanticsLabel: option.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final bool disabled = states.contains(WidgetState.disabled);
          final bool hovered = states.contains(WidgetState.hovered);
          final bool pressed = states.contains(WidgetState.pressed);

          final Color ringInk;
          final Color coreInk;
          final double ringWidth;
          if (selected) {
            // radio_button.dart:320-333.
            ringInk = fluentCheckedInputColor(theme, states);
            coreInk = res.textOnAccentFillColorPrimary;
            ringWidth = disabled
                ? 4.0
                : hovered && !pressed
                ? 3.4
                : 5.0;
          } else {
            // radio_button.dart:334-352.
            ringInk = disabled
                ? res.textFillColorDisabled
                : pressed
                ? theme.accent.defaultBrushFor(theme.brightness)
                : res.textFillColorTertiary;
            coreInk = disabled
                ? res.controlAltFillColorDisabled
                : pressed
                ? res.controlAltFillColorQuarternary
                : hovered
                ? res.controlAltFillColorTertiary
                : res.controlAltFillColorSecondary;
            ringWidth = pressed ? 4.5 : 1;
          }

          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  // The radio answers on the fast step
                  // (radio_button.dart:171-173).
                  duration: FluentMotion.fast,
                  curve: FluentMotion.curve,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: coreInk,
                    border: Border.all(color: ringInk, width: ringWidth),
                  ),
                ),
                // The 6 epx content gap (radio_button.dart:196).
                const SizedBox(width: 6),
                Text(
                  option.label,
                  style: FluentTypeResolution.styleOf(context, TextRole.control)
                      .copyWith(
                        color: disabled
                            ? res.textFillColorDisabled
                            : res.textFillColorPrimary,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The Fluent answer to `SkinControls.filterToggle`: a WinUI ToggleButton.
///
/// A checked ToggleButton wears the checked-input accent ramp under the
/// on-accent foreground and the accent's flattening border; unchecked it is
/// the standard button (fluent_ui@4.16.1
/// lib/src/controls/inputs/toggle_button.dart:150-170, delegating to the
/// standard and filled button tables). The count rides in the label - "the
/// label (n)" - because WinUI has no chip and a null count already means
/// "do not say". The icon slot waits on the Fluent glyph table.
final class FluentFilterToggle extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentFilterToggle({super.key, required this.spec});

  /// What the application declared.
  final FilterToggleSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final String label = spec.count == null
        ? spec.label
        : '${spec.label} (${spec.count})';
    return Semantics(
      toggled: spec.selected,
      child: FluentPressable(
        onPressed: spec.enabled ? () => spec.onSelected(!spec.selected) : null,
        semanticsLabel: spec.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fill;
          final Color foreground;
          if (spec.selected) {
            // toggle_button.dart:162-169.
            fill = fluentCheckedInputColor(theme, states);
            foreground = states.contains(WidgetState.pressed)
                ? res.textOnAccentFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.textOnAccentFillColorDisabled
                : res.textOnAccentFillColorPrimary;
          } else {
            // The standard button tables (buttons/theme.dart:292-323).
            fill = states.contains(WidgetState.pressed)
                ? res.controlFillColorTertiary
                : states.contains(WidgetState.hovered)
                ? res.controlFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.controlFillColorDisabled
                : res.controlFillColorDefault;
            foreground = states.contains(WidgetState.pressed)
                ? res.textFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.textFillColorDisabled
                : res.textFillColorPrimary;
          }
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              padding: FluentGeometry.buttonPadding,
              decoration: ShapeDecoration(
                color: fill,
                shape: fluentControlOutline(theme, states),
              ),
              child: Text(
                label,
                style: FluentTypeResolution.styleOf(
                  context,
                  TextRole.control,
                ).copyWith(color: foreground),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The Fluent answer to `SkinControls.dropdown`: the WinUI ComboBox.
///
/// The CLOSED box is the standard button's colour tables under the control
/// corner (fluent_ui@4.16.1 lib/src/controls/form/combo_box.dart:26,
/// `kComboBoxRadius` 4; the box resolves the standard `buttonColor`
/// ladder), with the value on the left and the `ChevronDown` mark on the
/// right (:978). The OPEN list renders in place beneath the box until the
/// overlay facet lands - the ComboBox's dropdown is a flyout, and this
/// slice registers that gap rather than half-building an overlay of its
/// own. Every row is its own focusable pressable, so the open list is
/// walked with Tab and confirmed with Enter.
final class FluentComboBox<T> extends StatefulWidget {
  /// Draws [spec] in Fluent.
  const FluentComboBox({super.key, required this.spec});

  /// What the application declared.
  final DropdownSpec<T> spec;

  @override
  State<FluentComboBox<T>> createState() => _FluentComboBoxState<T>();
}

class _FluentComboBoxState<T> extends State<FluentComboBox<T>> {
  bool _open = false;

  String get _shown {
    for (final DropdownOption<T> option in widget.spec.options) {
      if (option.value == widget.spec.value) return option.label;
    }
    return widget.spec.hint ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final DropdownSpec<T> spec = widget.spec;
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool operable = spec.enabled && spec.onChanged != null;
    final bool placeholder = spec.value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (spec.label.isNotEmpty)
          Padding(
            // The InfoLabel arrangement (utils/info_label.dart:52,63).
            padding: const EdgeInsetsDirectional.only(bottom: 4),
            child: Text(
              spec.label,
              style: FluentTypeResolution.styleOf(context, TextRole.body)
                  .copyWith(
                    color: operable
                        ? res.textFillColorPrimary
                        : res.textFillColorDisabled,
                  ),
            ),
          ),
        FluentPressable(
          onPressed: operable ? () => setState(() => _open = !_open) : null,
          semanticsLabel: spec.label,
          focusNode: spec.focusNode,
          autofocus: spec.autofocus,
          builder: (BuildContext context, Set<WidgetState> states) {
            // The standard button's fill and label tables
            // (buttons/theme.dart:292-323), which is what the ComboBox
            // resolves for its closed box.
            final Color fill = states.contains(WidgetState.pressed)
                ? res.controlFillColorTertiary
                : states.contains(WidgetState.hovered)
                ? res.controlFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.controlFillColorDisabled
                : res.controlFillColorDefault;
            final Color foreground = states.contains(WidgetState.disabled)
                ? res.textFillColorDisabled
                : placeholder
                ? res.textFillColorSecondary
                : states.contains(WidgetState.pressed)
                ? res.textFillColorSecondary
                : res.textFillColorPrimary;
            return FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                padding: FluentGeometry.buttonPadding,
                decoration: ShapeDecoration(
                  color: fill,
                  shape: fluentControlOutline(theme, states),
                ),
                child: Row(
                  mainAxisSize: spec.fillWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: <Widget>[
                    if (spec.fillWidth)
                      Expanded(
                        child: Text(
                          _shown,
                          overflow: TextOverflow.ellipsis,
                          style: FluentTypeResolution.styleOf(
                            context,
                            TextRole.control,
                          ).copyWith(color: foreground),
                        ),
                      )
                    else
                      Text(
                        _shown,
                        style: FluentTypeResolution.styleOf(
                          context,
                          TextRole.control,
                        ).copyWith(color: foreground),
                      ),
                    // One statement's two parts apart (FluentMetrics.spaceS).
                    const SizedBox(width: FluentMetrics.spaceS),
                    // ChevronDown closed, up while open
                    // (combo_box.dart:978).
                    FluentChevron(color: foreground, turns: _open ? 2 : 0),
                  ],
                ),
              ),
            );
          },
        ),
        if (_open)
          for (final DropdownOption<T> option in spec.options)
            _ComboRow<T>(
              option: option,
              selected: option.value == spec.value,
              fillWidth: spec.fillWidth,
              onSelected: option.enabled
                  ? () {
                      setState(() => _open = false);
                      spec.onChanged!(option.value);
                    }
                  : null,
            ),
      ],
    );
  }
}

/// One row of the opened list: the subtle ladder under body text, the
/// chosen row resting on the standing subtle fill.
final class _ComboRow<T> extends StatelessWidget {
  const _ComboRow({
    required this.option,
    required this.selected,
    required this.fillWidth,
    required this.onSelected,
  });

  final DropdownOption<T> option;
  final bool selected;
  final bool fillWidth;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Semantics(
      selected: selected,
      child: FluentPressable(
        onPressed: onSelected,
        semanticsLabel: option.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final bool disabled = states.contains(WidgetState.disabled);
          final Color fill = states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered) || selected
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;
          return AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            width: fillWidth ? double.infinity : null,
            // The dense list rhythm (surfaces/list_tile.dart:8-12).
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
            ),
            child: Row(
              mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTypeResolution.styleOf(context, TextRole.body)
                        .copyWith(
                          color: disabled
                              ? res.textFillColorDisabled
                              : res.textFillColorPrimary,
                        ),
                  ),
                ),
                if (option.detail != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      option.detail!,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.detail,
                      ).copyWith(color: res.textFillColorSecondary),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The one-stroke control outline per state: the gradient elevation stroke
/// at rest and hover, flattening to the solid default stroke while pressed
/// or disabled (buttons/theme.dart:326-350) - shared by the filter toggle
/// and the combo box so the two cannot drift from the button.
ShapeBorder fluentControlOutline(
  FluentThemeData theme,
  Set<WidgetState> states,
) {
  final FluentResources res = theme.resources;
  final BorderRadius corner = BorderRadius.circular(
    FluentGeometry.controlCornerRadius,
  );
  if (states.contains(WidgetState.pressed) ||
      states.contains(WidgetState.disabled)) {
    return FluentStrokeBorder.solid(
      color: res.controlStrokeColorDefault,
      borderRadius: corner,
    );
  }
  return FluentStrokeBorder.gradient(
    // buttons/theme.dart:337-349.
    gradient: LinearGradient(
      begin: Alignment.center,
      end: const Alignment(0, 3),
      colors: <Color>[
        res.controlStrokeColorSecondary,
        res.controlStrokeColorDefault,
      ],
      stops: const <double>[0.3, 1.0],
    ),
    borderRadius: corner,
  );
}
