import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_button.dart';
import '../controls/fluent_checkbox.dart';
import '../controls/fluent_choice_controls.dart';
import '../controls/fluent_control_marks.dart';
import '../controls/fluent_fields.dart';
import '../controls/fluent_icon_button.dart';
import '../controls/fluent_pressable.dart';
import '../controls/fluent_progress.dart';
import '../controls/fluent_slider.dart';
import '../controls/fluent_toggle_switch.dart';
import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';

/// Things you operate, drawn against WinUI - the Fluent answer to
/// `SkinControls`, with no widget library underneath.
///
/// Fifteen members, each delegating to a control this package draws itself:
/// every colour is a WinUI resource out of `FluentResources`, every metric
/// carries its provenance at the site, and every stateful control rides
/// [FluentPressable] - so hover, press, focus and keyboard activation
/// behave identically across the facet and are measured once by the
/// behaviour suite.
///
/// **The registered gaps of this slice**, reported rather than hidden, in
/// the order they will close:
///
///  * **The Fluent glyph table does not exist yet** (the decision
///    `FluentButton`'s doc registers). Every [IconRole] slot - an icon
///    button's mark, a button's `leading`/`trailing`, a field's `leading`,
///    a row's or option's icon - reserves its exact box on the Fluent icon
///    ramp and draws nothing in it. Control-ANATOMY marks (the check, the
///    mixed bar, the chevron) are not affected: they are drawn geometry in
///    `fluent_control_marks.dart`, parts of their control like a switch's
///    knob.
///  * **This skin has no overlay facet yet**, so every `tooltip` is
///    announced to the semantics tree instead of shown, the date field is
///    typed instead of opening the DatePicker flyout, and the suggest and
///    combo lists open in place beneath their box instead of in a flyout.
///  * **`ButtonSpec.tone` beyond accent/neutral** stays unanswered: WinUI
///    has no published danger-button fill, and rounding `Tone.danger` onto
///    a red accent would be inventing - a contract finding to settle
///    against the Fluent 2 spec.
///  * **[ControlScale] on worded controls is Fluent's known collapse**: the
///    language has one control height, so the three scales draw one box;
///    mark-only controls DO scale, on the published 12/16/20 icon ramp.
final class FluentControls implements SkinControls {
  /// Builds the controls facet.
  const FluentControls();

  /// **What can the user do here, in words?**
  ///
  /// [FluentButton]: the four [Emphasis] values on WinUI's four button
  /// treatments, with the colour tables, elevation stroke and motion pinned
  /// by the behaviour suite.
  @override
  Widget button(BuildContext context, ButtonSpec spec) =>
      FluentButton(spec: spec);

  /// **What can the user do here, as a mark?**
  ///
  /// [FluentIconButton]: the subtle ladder, the ToggleButton's checked
  /// treatment for `selected`, the InfoBadge for a count.
  @override
  Widget iconButton(BuildContext context, IconButtonSpec spec) =>
      FluentIconButton(spec: spec);

  /// **What is the application asking the user to type?**
  ///
  /// [FluentTextField]: the WinUI TextBox under the InfoLabel arrangement.
  /// The spec arrives already resolved by `SkinFormFieldHost`, so `error`
  /// is the one message to show and `onChanged` already reports to the
  /// form - this member must not register a second time.
  @override
  Widget textField(
    BuildContext context,
    FieldSpec spec,
    FieldHandles handles,
  ) => FluentTextField(spec: spec, handles: handles);

  /// **Which moment is the application asking the user to name?**
  ///
  /// [FluentDateField]: typed ISO in the TextBox shell, range enforced;
  /// the DatePicker flyout waits on the overlay facet.
  @override
  Widget dateField(
    BuildContext context,
    DateFieldSpec spec,
    FieldHandles handles,
  ) => FluentDateField(spec: spec, handles: handles);

  /// **Which item of a closed list is the user narrowing towards?**
  ///
  /// [FluentSuggestField]: the AutoSuggestBox's box exactly; its list in
  /// place until the overlay facet lands.
  @override
  Widget suggestField<T>(
    BuildContext context,
    SuggestFieldSpec<T> spec,
    FieldHandles handles,
  ) => FluentSuggestField<T>(spec: spec, handles: handles);

  /// **Is this fact true?**
  ///
  /// [FluentCheckbox]: the 20 epx box, the input well, the accent ramp,
  /// the drawn check and the mixed bar.
  @override
  Widget checkbox(BuildContext context, ToggleSpec spec) =>
      FluentCheckbox(spec: spec);

  /// **Is this setting on?**
  ///
  /// [FluentToggleSwitch]: the 40 x 20 stadium and the knob that stretches
  /// toward the pointer.
  @override
  Widget toggle(BuildContext context, ToggleSpec spec) =>
      FluentToggleSwitch(spec: spec);

  /// **Is this named fact true?**
  ///
  /// Fluent's own idiom is the control WITH its content slot -
  /// `Checkbox(content:)` at an 8 epx gap (inputs/checkbox.dart:199-204),
  /// `ToggleSwitch(content:)` at 10 (inputs/toggle_switch.dart:255-262) -
  /// the whole row one pressable, the description below the words in the
  /// caption step and secondary ink (the reference's ListTile subtitle
  /// treatment, surfaces/list_tile.dart:311).
  @override
  Widget toggleRow(BuildContext context, ToggleRowSpec spec) =>
      _FluentToggleRow(spec: spec);

  /// **Where along this range is the user?**
  ///
  /// [FluentSlider]: the 3.75 epx track, the breathing thumb, arrow-key
  /// steps.
  @override
  Widget slider(BuildContext context, SliderSpec spec) =>
      FluentSlider(spec: spec);

  /// **Which one of these is it?**
  ///
  /// [FluentComboBox]: the standard button's tables under the control
  /// corner, the chevron, the list in place until the overlay facet lands.
  @override
  Widget dropdown<T>(BuildContext context, DropdownSpec<T> spec) =>
      FluentComboBox<T>(spec: spec);

  /// **Which one of these few is it?**
  ///
  /// [FluentChoiceGroup]: a WinUI radio group - the decomposition the
  /// contract's doc records for this member.
  @override
  Widget choiceGroup<T>(BuildContext context, ChoiceGroupSpec<T> spec) =>
      FluentChoiceGroup<T>(spec: spec);

  /// **Is this condition on?**
  ///
  /// [FluentFilterToggle]: a WinUI ToggleButton, the count in the words.
  @override
  Widget filterToggle(BuildContext context, FilterToggleSpec spec) =>
      FluentFilterToggle(spec: spec);

  /// **Which of the skin's own colours does this object get?**
  ///
  /// The swatches are `FluentInk.series` - seven, the reference's accent
  /// families minus yellow, and the LENGTH is as much this skin's answer
  /// as the palette. Each swatch is a 20 epx box at the control corner;
  /// the chosen one carries the drawn check in the contrast-correct
  /// foreground (`FluentInk.foregroundOn`), which is this skin deciding a
  /// weight for a slot the role vocabulary refuses to carry - the same
  /// judgement the Material picker records.
  @override
  Widget seriesPicker(BuildContext context, SeriesPickerSpec spec) =>
      _FluentSeriesPicker(spec: spec);

  /// **How far along is this, and how much room may saying so take?**
  ///
  /// The WinUI pair: [FluentProgressBar] inline, [FluentProgressRing] as a
  /// block. A null fraction is genuinely indeterminate in both forms -
  /// Fluent is not the language with the registered loss here.
  @override
  Widget progress(
    BuildContext context, {
    double? fraction,
    required ProgressExtent extent,
  }) => switch (extent) {
    ProgressExtent.inline => FluentProgressBar(fraction: fraction),
    ProgressExtent.block => Center(
      child: FluentProgressRing(fraction: fraction),
    ),
  };

  /// **What does this thing do, for someone who cannot tell by looking?**
  ///
  /// Announced, not yet shown: the Fluent tooltip is a flyout surface and
  /// this skin has no overlay facet - the same registered gap every
  /// `tooltip` parameter in this facet carries. The message reaches the
  /// semantics tree, and the child is mounted through its port so the
  /// attribution boundary is planted exactly as the contract requires.
  @override
  Widget describedBy(
    BuildContext context, {
    required String message,
    required ContentPort child,
  }) => Semantics(tooltip: message, child: child.mount());
}

/// The labelled toggle row: one pressable, the control at its head.
final class _FluentToggleRow extends StatelessWidget {
  const _FluentToggleRow({required this.spec});

  final ToggleRowSpec spec;

  bool get _operable => spec.enabled && spec.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    // The reference's content gaps: 8 beside a checkbox
    // (inputs/checkbox.dart:199-204), 10 beside a switch
    // (inputs/toggle_switch.dart:255-262).
    final double gap = switch (spec.kind) {
      ToggleKind.check => 8,
      ToggleKind.switching => 10,
    };
    return Semantics(
      checked: spec.value ?? false,
      mixed: spec.value == null,
      child: FluentPressable(
        onPressed: _operable ? () => spec.onChanged!(spec.value != true) : null,
        semanticsLabel: spec.label,
        builder: (BuildContext context, Set<WidgetState> states) =>
            FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: Row(
                crossAxisAlignment: spec.description == null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  switch (spec.kind) {
                    ToggleKind.check => FluentCheckboxBox(
                      value: spec.value,
                      states: states,
                    ),
                    ToggleKind.switching => FluentToggleSwitchTrack(
                      on: spec.value ?? false,
                      states: states,
                    ),
                  },
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          spec.label,
                          style:
                              FluentTypeResolution.styleOf(
                                context,
                                TextRole.body,
                              ).copyWith(
                                color: _operable
                                    ? res.textFillColorPrimary
                                    : res.textFillColorDisabled,
                              ),
                        ),
                        if (spec.description != null)
                          Text(
                            spec.description!,
                            style:
                                FluentTypeResolution.styleOf(
                                  context,
                                  TextRole.detail,
                                ).copyWith(
                                  color: _operable
                                      ? res.textFillColorSecondary
                                      : res.textFillColorDisabled,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// The colour picker over this skin's own series.
final class _FluentSeriesPicker extends StatelessWidget {
  const _FluentSeriesPicker({required this.spec});

  final SeriesPickerSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Semantics(
      label: spec.label,
      container: true,
      child: Wrap(
        spacing: FluentMetrics.spaceS,
        runSpacing: FluentMetrics.spaceS,
        children: <Widget>[
          for (int index = 0; index < FluentInk.seriesLength; index++)
            _Swatch(
              index: index,
              color: FluentInk.series(theme.brightness, index),
              selected: index == spec.selectedIndex,
              onSelected: () => spec.onSelected(index),
            ),
        ],
      ),
    );
  }
}

/// One swatch: a box in the series colour at the control corner, the
/// chosen one marked with the drawn check.
final class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.index,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Semantics(
      selected: selected,
      child: FluentPressable(
        onPressed: onSelected,
        semanticsLabel: '$index',
        builder: (BuildContext context, Set<WidgetState> states) =>
            FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(
                    FluentGeometry.controlCornerRadius,
                  ),
                  // Every swatch wears the strong stroke an input wears, so
                  // a light swatch holds its edge on a light paper.
                  border: Border.all(
                    color: res.controlStrongStrokeColorDefault,
                  ),
                ),
                child: selected
                    ? Center(
                        child: FluentCheckMark(
                          color: FluentInk.foregroundOn(color),
                        ),
                      )
                    : null,
              ),
            ),
      ),
    );
  }
}
