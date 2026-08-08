// This file is where Material's own control widgets are reached. The
// design-system rules ban them app-wide precisely so that keyboard focus,
// state layers and tap targets cannot be hand-rolled twice - and delegating to
// the canonical widget IS this file's job, which is why the bans are lifted
// here and nowhere else in the package. It is the same arrangement, and the
// same reasoning, that `base_button.dart`, `base_text_field.dart` and
// `base_dialog.dart` already carry in the application; the bodies below were
// moved out of those files.
// ignore_for_file: avoid_filled_button, avoid_outlined_button
// ignore_for_file: avoid_text_button, avoid_icon_button, avoid_text_field
// ignore_for_file: avoid_dropdown_button_form_field, avoid_filter_chip
// ignore_for_file: avoid_choice_chip, avoid_badge
//
// `avoid_text_with_style` is lifted for the same reason the blueprint package
// lifts it wholesale, and it cannot be obeyed here in either the letter or the
// spirit: `BaseLabel` lives in the application package, which the isolation
// gate makes unreachable from a skin, and the rule exists to stop APPLICATION
// code deciding what text looks like - which is precisely this layer's job.
// Every style below is a step of the ambient `TextTheme` rather than an ad-hoc
// one, so the discipline the rule stands for is kept by the code.
// ignore_for_file: avoid_text_with_style

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:intl/intl.dart';

import '../material_glyphs.dart';
import '../material_ink.dart';

/// Things you operate, in Material 3.
///
/// **Extracted, not rewritten.** Every body here was moved out of a `Base*`
/// component that had already been rebuilt on Material's canonical widgets:
/// `base_button.dart` ([button], [iconButton]), `base_text_field.dart`
/// ([textField]), `base_date_field.dart` ([dateField]), `base_dropdown.dart`
/// ([dropdown], [suggestField]), `base_filter_chip.dart` ([filterToggle],
/// [choiceGroup]) and `base_animated_widgets.dart` ([checkbox], [toggle]).
/// `base_select_all_button.dart` contributes no member: it is a composition
/// over [button] and [iconButton] - a glyph and a word chosen from application
/// meaning - and stays in application code.
///
/// Three behaviours in here were paid for with defects and are called out at
/// the member that carries them, because a move is exactly where such a thing
/// gets dropped:
///
///  * [button] does not name a `shape`, so the control corner keeps arriving
///    from the theme's radius tokens (#399);
///  * [textField] does not spell out its own borders, so the SDK keeps
///    resolving all four states including hover;
///  * [toggle] resolves its colours PER STATE, so an active colour can never
///    be applied to an inactive or disabled switch.
///
/// **What the seven-value `ButtonVariant` became.** The application asked for
/// `primary | secondary | tertiary | danger | ghost | success |
/// dangerSecondary`; the contract asks for an [Emphasis] and a [Tone], because
/// `dangerSecondary` was a Material compound while "quiet, and destructive" is
/// a meaning three languages can each answer their own way. The mapping back
/// is exact and total, which is what lets this extraction be pixel-neutral:
///
/// | was | emphasis | tone | renders as |
/// |---|---|---|---|
/// | `primary` | `primary` | `accent` | `FilledButton`, primary/onPrimary |
/// | `danger` | `primary` | `danger` | `FilledButton`, error/onError |
/// | `success` | `primary` | `success` | `FilledButton`, the git green |
/// | `secondary` | `secondary` | `accent` | `OutlinedButton`, stock side |
/// | `dangerSecondary` | `secondary` | `danger` | `OutlinedButton`, error side |
/// | `tertiary` | `link` | `accent` | `TextButton`, primary label |
/// | `ghost` | `quiet` | `neutral` | `TextButton`, onSurface label (BTN-006) |
final class MaterialControls implements SkinControls {
  /// Builds the controls facet.
  const MaterialControls();

  /// **What can the user do here, in words?**
  ///
  /// `BaseButton.build`, moved. Every property this member *owns* is pinned at
  /// the widget so conformance stays deterministic: the label style and the
  /// glyph size are per-scale decisions this member makes, and neither may
  /// leak in from a sub-theme. The padded tap target plus standard density
  /// guarantee the >= 48 dp hit area around every container size.
  ///
  /// **`shape` is deliberately absent, and that absence is load-bearing
  /// (#399).** `ButtonStyleButton` resolves the widget's style BEFORE
  /// `themeStyleOf`, so any widget-level shape makes the corner unreachable
  /// from the theme forever - which is exactly how the configured
  /// `filledButtonRadius` / `outlinedButtonRadius` / `textButtonRadius` tokens
  /// came to govern nothing. Leaving the slot empty hands the control corner
  /// to those tokens, and BTN-001 does not weaken by moving: the conformance
  /// suite measures the corner this actually RENDERS under the real theme and
  /// compares it against the M3 stadium oracle, so should the token ever stop
  /// arriving the button falls back to the stadium and the entry fails as a
  /// STALE deviation rather than passing quietly.
  @override
  Widget button(BuildContext context, ButtonSpec spec) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isEffectivelyDisabled = spec.isLoading || spec.onPressed == null;
    final VoidCallback? onPressed = isEffectivelyDisabled
        ? null
        : spec.onPressed;

    // Per-scale metrics. `normal` is the stock M3 button; `compact` and
    // `prominent` are the registered desktop sizes (BTN-002..BTN-005). Where
    // padding is null the framework's scaled padding applies.
    final (
      TextStyle? labelStyle,
      double glyphSize,
      Size minimumSize,
      EdgeInsetsGeometry? padding,
    ) = switch (spec.scale) {
      // BTN-002 container, BTN-003 label, BTN-004 glyph; the 48 dp minimum
      // width keeps even a one-character compact button a full hit target.
      ControlScale.compact => (
        textTheme.labelMedium,
        MaterialMetrics.iconS,
        const Size(48, 32),
        const EdgeInsets.symmetric(horizontal: MaterialMetrics.spaceM),
      ),
      ControlScale.normal => (
        textTheme.labelLarge,
        _stockButtonGlyph,
        const Size(64, 40),
        null,
      ),
      // BTN-005 container.
      ControlScale.prominent => (
        textTheme.labelLarge,
        _stockButtonGlyph,
        const Size(64, 48),
        null,
      ),
    };

    final ButtonStyle style = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
      iconSize: WidgetStatePropertyAll<double>(glyphSize),
      minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
      padding: padding == null
          ? null
          : WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_buttonPaint(context, spec.emphasis, spec.tone));

    final Widget child = _buttonContent(context, spec, glyphSize);

    final Widget button = switch (_familyOf(spec.emphasis)) {
      _ButtonFamily.filled => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      _ButtonFamily.outlined => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      _ButtonFamily.text => TextButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    };

    final Widget sized = spec.fillWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;

    // The spec carries a tooltip the application's `BaseButton` had no slot
    // for, and it is most useful in exactly the case a label cannot cover:
    // the REASON a button is unavailable. A `Tooltip` still shows over a
    // disabled child, which a wrapper is the only way to get.
    if (spec.tooltip == null) return sized;
    return Tooltip(message: spec.tooltip!, child: sized);
  }

  /// **What can the user do here, as a mark?**
  ///
  /// `BaseIconButton.build`, moved. Every measured property is pinned at the
  /// widget so conformance stays deterministic regardless of icon-button
  /// sub-themes or the ambient `IconTheme`.
  ///
  /// Unlike [button], this one has to NAME its corner: `FlexSubThemesData`
  /// exposes a radius token for every button family except the icon button -
  /// there is no `iconButtonRadius` - so no configured token can reach an
  /// `IconButton`, and ICO-001 is carried by the constant instead. Reading the
  /// same rung of the corner scale the theme's button radii are configured
  /// from is what keeps the two members on one corner, and
  /// `theme_token_reach_test.dart` asserts they still agree, so the constant
  /// cannot drift away from the tokens unnoticed.
  @override
  Widget iconButton(BuildContext context, IconButtonSpec spec) {
    final VoidCallback? onPressed = spec.onPressed;

    // Per-scale metrics. `normal` is the stock M3 container; `compact` and
    // `prominent` are the registered desktop sizes (ICO-002..ICO-005). The
    // container is the glyph plus the stock 8 dp padding, clamped up by the
    // minimum size, so 16+16 = 32 exactly and 20/24 sit centred in 40/48.
    final (double containerSize, double glyphSize) = switch (spec.scale) {
      // ICO-002 container, ICO-003 glyph.
      ControlScale.compact => (32.0, MaterialMetrics.iconS),
      // ICO-004 glyph.
      ControlScale.normal => (40.0, MaterialMetrics.iconM),
      // ICO-005 container.
      ControlScale.prominent => (48.0, MaterialMetrics.iconL),
    };

    ButtonStyle style = ButtonStyle(
      iconSize: WidgetStatePropertyAll<double>(glyphSize),
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(containerSize)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(MaterialMetrics.spaceS),
      ),
      // ICO-001: the shared control corner instead of the M3 stadium.
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_iconButtonPaint(context, spec.emphasis, spec.tone));

    if (spec.selected ?? false) {
      // The selected treatment recolours the glyph only: the state layers keep
      // deriving from the emphasis foreground, and the disabled treatment
      // always wins, so the selected tint never survives into disabled.
      final ColorScheme colors = Theme.of(context).colorScheme;
      style = style.copyWith(
        iconColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return _disabledForeground(colors);
          }
          return colors.primary;
        }),
      );
    }

    // The glyph carries no size or colour: the style's `IconTheme` applies
    // both. `isSelected` passes through so the framework's own toggle support
    // maintains `WidgetState.selected` and the selected semantics.
    //
    // The WEIGHT is decided here, and this is the slot that knows enough to
    // decide it. A role carries none by design (conflict C3), while the
    // application has always said "this one is on" with a SOLID mark as well
    // as a tint: a favourited repository's star and an engaged filter's
    // funnel were written as `PhosphorIconsFill.*` at the call site, beside
    // the very `isSelected` flag that arrives here as `spec.selected`. So the
    // fill is not lost at the seam, it is re-decided on this side of it, by
    // the member filling the slot - which is the same shape the census
    // already gave `boldOf` for dense surfaces. `filledOf` answers with the
    // ordinary mark for the roles that have no solid variant, so a selected
    // control whose mark was never drawn solid is unaffected.
    //
    // **Two image baselines are stale because of this line** and have to be
    // regenerated on Linux: `base_icon_button_selected_light.png` and
    // `base_icon_button_selected_dark.png`. They were captured while the
    // application built Material's `IconButton` itself and drew `Icon(icon)`
    // verbatim, so they encode "selection does not change the mark" — which
    // this application has always contradicted at three sites. The scene at
    // `test/conformance/goldens/component_scenes.dart` carries the full
    // reasoning, including why no edit to the scene can hold the baseline.
    // The weight itself is asserted on every platform by
    // `test/conformance/components/base_icon_button_conformance_test.dart`,
    // so the images are not the only thing that knows.
    final Widget mark = Icon(
      (spec.selected ?? false)
          ? MaterialGlyphs.filledOf(spec.icon)
          : MaterialGlyphs.of(spec.icon),
    );
    final Widget control = switch (_familyOf(spec.emphasis)) {
      _ButtonFamily.filled => IconButton.filled(
        onPressed: onPressed,
        icon: mark,
        tooltip: spec.tooltip,
        isSelected: spec.selected,
        style: style,
      ),
      _ButtonFamily.outlined => IconButton.outlined(
        onPressed: onPressed,
        icon: mark,
        tooltip: spec.tooltip,
        isSelected: spec.selected,
        style: style,
      ),
      _ButtonFamily.text => IconButton(
        onPressed: onPressed,
        icon: mark,
        tooltip: spec.tooltip,
        isSelected: spec.selected,
        style: style,
      ),
    };

    // A count riding on the mark. `Badge` is Material's own answer and it
    // positions itself over the child, which is why the count is a wrapper
    // rather than something drawn into the glyph.
    if (spec.badgeCount == null) return control;
    return Badge.count(count: spec.badgeCount!, child: control);
  }

  /// **What is the application asking the user to type?**
  ///
  /// `BaseTextField`, moved. The spec arrives already resolved by
  /// `SkinFormFieldHost`: `error` is the one message to show and `onChanged`
  /// has already reported to the enclosing `Form`.
  ///
  /// **That host is where a paid-for defect now lives.** The application's
  /// field reached for `TextFormField` rather than `TextField` because a
  /// `TextField` never runs a validator, so every dialog's
  /// `formKey.currentState!.validate()` found no fields and waved invalid
  /// input through. The registration did not disappear in this move - it moved
  /// UP, into the contract package, so that a skin whose canonical text
  /// control cannot register with a `Form` at all is registered anyway. This
  /// member is therefore free to render a plain `TextField`, and must not
  /// register a second time.
  @override
  Widget textField(
    BuildContext context,
    FieldSpec spec,
    FieldHandles handles,
  ) => _MaterialTextField(spec: spec, handles: handles);

  /// **Which moment is the application asking the user to name?**
  ///
  /// `BaseDateField`, moved. It is the same M3 component a text field is - an
  /// `InputDecorator` around a value - so it speaks the text field's state
  /// language rather than a button's: hover darkens the outline to `onSurface`
  /// and focus draws it in `primary` at 2 dp, both driven by
  /// `InputDecorator.isHovering` and `isFocused`.
  ///
  /// That is why the tap surface is a `FocusableActionDetector` and not an
  /// `InkWell`: an ink layer would paint a hover and focus highlight ON TOP OF
  /// those two, which is the "never two affordances for one job" defect, and
  /// before the outline shape was passed down it painted them as a square
  /// behind the rounded field.
  @override
  Widget dateField(
    BuildContext context,
    DateFieldSpec spec,
    FieldHandles handles,
  ) => _MaterialDateField(spec: spec, handles: handles);

  /// **Which item of a closed list is the user narrowing towards?**
  ///
  /// `SearchableBaseDropdown`, moved: a `LayerLink`, an `OverlayEntry` and a
  /// `CompositedTransformFollower`, with the field's own search box inside the
  /// overlay and the list filtered beneath it.
  @override
  Widget suggestField<T>(
    BuildContext context,
    SuggestFieldSpec<T> spec,
    FieldHandles handles,
  ) => _MaterialSuggestField<T>(spec: spec, handles: handles);

  /// **Is this fact true?**
  ///
  /// `BaseCheckbox`, moved. The caller's `activeColor` and `checkColor` are
  /// gone, and their absence is the contract working: a `Color?` parameter is
  /// exactly what the spine rule bans, so what a checkbox looks like is this
  /// skin's decision and `CheckboxThemeData` is where it makes it.
  ///
  /// `tristate` follows the value rather than being asked for, because the
  /// mixed state is never something a USER requests - it is what the
  /// application reports about a folder whose children are only partly
  /// selected. Material asserts `tristate || value != null`, so a mixed value
  /// has to switch it on; a definite value leaves it off, which is what stops
  /// the user cycling a plain checkbox into a mixed state nothing asked for.
  @override
  Widget checkbox(BuildContext context, ToggleSpec spec) {
    final bool operable = spec.enabled && spec.onChanged != null;
    return Semantics(
      label: spec.label,
      child: Checkbox(
        value: spec.value,
        tristate: spec.value == null,
        onChanged: operable ? spec.onChanged : null,
      ),
    );
  }

  /// **Is this setting on?**
  ///
  /// `BaseSwitch`, moved, including [_perState] - which is the part that
  /// matters. The active colours were once handed straight to `thumbColor` and
  /// `trackColor`, which applied them in EVERY state: an off switch wore the
  /// on colour, and the theme's disabled treatment was overwritten by it. The
  /// resolver is the fix, and it survives the move even though this skin
  /// currently resolves to nothing, because the moment a colour is attached
  /// here it has to go through it or the defect returns.
  @override
  Widget toggle(BuildContext context, ToggleSpec spec) {
    final bool operable = spec.enabled && spec.onChanged != null;

    // Both slots are empty because the colours a caller used to pass in are
    // gone with `ButtonVariant`'s siblings - banned by the spine rule - and
    // this skin's answer to "what does a switch look like" is `SwitchTheme`'s.
    // When neither colour is given the property itself is null, which leaves
    // the theme in full control.
    final WidgetStateProperty<Color?>? thumbColor = _perState(null, null);
    final WidgetStateProperty<Color?>? trackColor = _perState(null, null);

    return Semantics(
      label: spec.label,
      child: Switch(
        // A switch is a two-state control by construction, so the mixed value
        // reads as "not on". The mixed state itself belongs to `checkbox`,
        // which is the control that can draw it.
        value: spec.value ?? false,
        onChanged: operable ? (bool value) => spec.onChanged!(value) : null,
        thumbColor: thumbColor,
        trackColor: trackColor,
      ),
    );
  }

  /// **Is this named fact true?**
  ///
  /// The 36 labelled toggle rows the application builds with
  /// `CheckboxListTile` (26) and `SwitchListTile` (10), as one member. The
  /// content padding is deliberately left at the M3 default rather than pinned
  /// at zero: a row inside a dialog and a row inside a settings section want
  /// different insets, and which one it gets is the surface's decision rather
  /// than the row's.
  @override
  Widget toggleRow(BuildContext context, ToggleRowSpec spec) {
    final bool operable = spec.enabled && spec.onChanged != null;
    final Widget title = Text(spec.label);
    final Widget? description = spec.description == null
        ? null
        : Text(spec.description!);
    final Widget? leading = spec.leading == null
        ? null
        : Icon(MaterialGlyphs.of(spec.leading!));

    return switch (spec.kind) {
      ToggleKind.check => CheckboxListTile(
        value: spec.value,
        tristate: spec.value == null,
        onChanged: operable ? spec.onChanged : null,
        title: title,
        subtitle: description,
        secondary: leading,
      ),
      ToggleKind.switching => SwitchListTile(
        value: spec.value ?? false,
        onChanged: operable ? (bool value) => spec.onChanged!(value) : null,
        title: title,
        subtitle: description,
        secondary: leading,
      ),
    };
  }

  /// **Where along this range is the user?**
  ///
  /// The shallow-clone depth slider, moved out of
  /// `clone_repository_dialog.dart`. `divisions` quantises the value rather
  /// than drawing ticks, because the fact the application is stating is that a
  /// clone depth is a whole number of commits; ticks are this skin's answer to
  /// that fact.
  @override
  Widget slider(BuildContext context, SliderSpec spec) {
    final bool operable = spec.enabled && spec.onChanged != null;
    return Slider(
      // Clamped rather than trusted: a range the application narrows while a
      // value is already outside it is a real state, and Material asserts on
      // it rather than rendering.
      value: spec.value.clamp(spec.min, spec.max),
      min: spec.min,
      max: spec.max,
      divisions: spec.divisions,
      label: spec.valueLabel,
      onChanged: operable ? spec.onChanged : null,
      onChangeEnd: operable ? spec.onChangeEnd : null,
    );
  }

  /// **Which one of these is it?**
  ///
  /// `BaseDropdown`, moved. The decoration decides the border SHAPE and
  /// nothing else: the content padding and the minimum height are the M3
  /// defaults for an outlined field, floored at `kMinInteractiveDimension`.
  /// The dropdown used to set `isDense` and its own padding, which shrank it
  /// to 40 dp - below the minimum interactive dimension, and 15 dp shorter
  /// than a text field standing next to it in the same dialog (DROP-001).
  @override
  Widget dropdown<T>(BuildContext context, DropdownSpec<T> spec) {
    return DropdownButtonFormField<T>(
      isExpanded: spec.fillWidth,
      autofocus: spec.autofocus,
      focusNode: spec.focusNode,
      initialValue: spec.value,
      decoration: InputDecoration(
        labelText: spec.label.isEmpty ? null : spec.label,
        hintText: spec.hint,
        border: const OutlineInputBorder(),
        prefixIcon: spec.leading == null
            ? null
            : Icon(
                MaterialGlyphs.of(spec.leading!),
                size: MaterialMetrics.iconM,
              ),
      ),
      items: <DropdownMenuItem<T>>[
        for (final DropdownOption<T> option in spec.options)
          DropdownMenuItem<T>(
            value: option.value,
            enabled: option.enabled,
            child: _optionRow(context, option),
          ),
      ],
      onChanged: spec.enabled ? spec.onChanged : null,
    );
  }

  /// **Which one of these few is it?**
  ///
  /// `BaseChoiceGroup`, moved, with `_ChoiceChip` folded in - it was already
  /// private, because a lone choice chip is a Material idea with no
  /// counterpart in the other two languages and the group is what a skin can
  /// answer in any of them.
  ///
  /// `ChoiceChip` rather than `FilterChip`: single-select is what M3 calls a
  /// choice chip, and the two are different widgets even though they look
  /// alike here.
  @override
  Widget choiceGroup<T>(BuildContext context, ChoiceGroupSpec<T> spec) {
    return Semantics(
      label: spec.label,
      container: true,
      child: Wrap(
        spacing: MaterialMetrics.spaceS,
        runSpacing: MaterialMetrics.spaceS,
        children: <Widget>[
          for (final ChoiceOption<T> option in spec.options)
            _tooltipped(
              option.tooltip,
              ChoiceChip(
                selected: option.value == spec.selected,
                // A chip reports the state it would flip TO, so re-tapping the
                // chosen option arrives here as `false`. A single-choice group
                // has no "none" state to flip to, so that report is dropped
                // rather than passed on.
                onSelected: option.enabled
                    ? (bool isNowSelected) {
                        if (isNowSelected) spec.onSelected(option.value);
                      }
                    : null,
                label: _chipLabel(option.label),
                avatar: _chipAvatar(option.icon),
                // Same selection treatment as [filterToggle]: container and
                // outline instead of the M3 checkmark (CHIP-003).
                side: option.value == spec.selected
                    ? BorderSide(color: Theme.of(context).colorScheme.secondary)
                    : null,
                shape: _chipShape,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }

  /// **Is this condition on?**
  ///
  /// `BaseFilterChip`, moved. A selected chip is marked by its container and
  /// by an outline that turns `secondary`, rather than by the M3 checkmark
  /// (CHIP-001, CHIP-002). The outline keeps its 1 dp width so selecting a
  /// chip costs no width at all and a filter bar never reflows on a toggle.
  /// Everything else - container colours, the unselected outline, padding,
  /// label padding, density and the padded tap target - is left to the M3
  /// defaults.
  ///
  /// The application's `showCount` flag has no counterpart and needs none: a
  /// null count already means "do not say".
  @override
  Widget filterToggle(BuildContext context, FilterToggleSpec spec) {
    final String label = spec.count == null
        ? spec.label
        : '${spec.label} (${spec.count})';
    return FilterChip(
      selected: spec.selected,
      onSelected: spec.enabled ? spec.onSelected : null,
      label: _chipLabel(label),
      avatar: _chipAvatar(spec.icon),
      side: spec.selected
          ? BorderSide(color: Theme.of(context).colorScheme.secondary)
          : null,
      shape: _chipShape,
      showCheckmark: false,
    );
  }

  /// **Which of the skin's own colours does this object get?**
  ///
  /// The workspace and project colour picker, moved out of
  /// `project_dialog.dart`. It is the only member the application cannot work
  /// around: once `Tone.series` owns the palette AND its length, there is no
  /// legal way for a screen to find out how many swatches to offer, which is
  /// why the count comes from `MaterialInk.seriesPalette` here.
  @override
  Widget seriesPicker(BuildContext context, SeriesPickerSpec spec) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label: spec.label,
      container: true,
      child: Wrap(
        spacing: MaterialMetrics.spaceS,
        runSpacing: MaterialMetrics.spaceS,
        children: <Widget>[
          for (int index = 0; index < MaterialInk.seriesPalette.length; index++)
            Builder(
              builder: (BuildContext context) {
                final Color swatch = MaterialInk.series(index);
                final bool isSelected = index == spec.selectedIndex;
                return InkWell(
                  onTap: () => spec.onSelected(index),
                  borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
                  child: Container(
                    width: MaterialMetrics.iconXL * 2,
                    height: MaterialMetrics.iconXL * 2,
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(
                        MaterialMetrics.radiusM,
                      ),
                      border: isSelected
                          ? Border.all(color: colors.primary, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: swatch.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        // The heavier stroke, because a tick sitting on a
                        // saturated swatch has to survive the contrast: this
                        // is the skin deciding a WEIGHT, which is exactly the
                        // decision `IconRole` refuses to carry. Resolves to
                        // the same mark the named constant used to hold.
                        ? Icon(
                            MaterialGlyphs.boldOf(IconRole.check),
                            color: _swatchForeground(swatch),
                            size: MaterialMetrics.iconM,
                          )
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// **How far along is this, and how much room may saying so take?**
  ///
  /// The two indicator classes the application already uses, behind the one
  /// vocabulary whose neutral name matches all three canons exactly. A null
  /// [fraction] means the end is unknowable, which both classes draw as their
  /// indeterminate animation without being asked.
  @override
  Widget progress(
    BuildContext context, {
    double? fraction,
    required ProgressExtent extent,
  }) => switch (extent) {
    ProgressExtent.inline => LinearProgressIndicator(value: fraction),
    ProgressExtent.block => Center(
      child: CircularProgressIndicator(value: fraction),
    ),
  };

  /// **What does this thing do, for someone who cannot tell by looking?**
  ///
  /// The 11 raw `Tooltip(` sites, as one member. The child is mounted through
  /// its port, which is what plants the boundary the attribution walk resumes
  /// at - so wrapping content in an explanation can never become a way to
  /// exempt that content from the leak detector.
  @override
  Widget describedBy(
    BuildContext context, {
    required String message,
    required ContentPort child,
  }) => Tooltip(message: message, child: child.mount());

  // ---------------------------------------------------------------------
  // The button paint, moved out of `BaseButton._variantStyle` and
  // `BaseIconButton._variantStyle`.
  // ---------------------------------------------------------------------

  /// The stock M3 glyph size inside a button, which is not a rung of the icon
  /// scale: 18 sits between `iconS` and `iconM` because Material chose it for
  /// the button and this skin keeps that choice rather than rounding it onto a
  /// rung it was never on.
  static const double _stockButtonGlyph = 18;

  /// What an [Emphasis] means in Material's button vocabulary.
  ///
  /// Shared by [button] and [iconButton] so the two members can never map the
  /// same emphasis onto different weights. `quiet` and `link` both land on the
  /// text family: an icon-only control has no label to carry a link's
  /// emphasis, which is why the two collapse there and are told apart by their
  /// tone instead.
  static _ButtonFamily _familyOf(Emphasis emphasis) => switch (emphasis) {
    Emphasis.primary => _ButtonFamily.filled,
    Emphasis.secondary => _ButtonFamily.outlined,
    Emphasis.quiet || Emphasis.link => _ButtonFamily.text,
  };

  /// The M3 disabled foreground: `onSurface` at 38 %.
  ///
  /// Every emphasis shares it, together with the 12 % container and border, so
  /// no semantic tint ever survives into disabled - which is the whole reason
  /// a destructive button stops looking destructive once it cannot be pressed.
  static Color _disabledForeground(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: 0.38);

  /// The M3 disabled container and border: `onSurface` at 12 %.
  static Color _disabledContainer(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: 0.12);

  /// The colours an [Emphasis] and a [Tone] mean on a worded button.
  ///
  /// Expressed through the concrete class's `styleFrom` so the state layers
  /// derive from the right foreground with the M3 opacities (pressed and
  /// focused 10 %, hovered 8 %) rather than being painted by hand.
  static ButtonStyle _buttonPaint(
    BuildContext context,
    Emphasis emphasis,
    Tone tone,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color disabledForeground = _disabledForeground(colors);
    final Color disabledContainer = _disabledContainer(colors);

    switch (_familyOf(emphasis)) {
      case _ButtonFamily.filled:
        final Color container = MaterialInk.foreground(context, tone);
        return FilledButton.styleFrom(
          backgroundColor: container,
          foregroundColor: _onFilled(colors, tone, container),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case _ButtonFamily.outlined:
        final ButtonStyle base = OutlinedButton.styleFrom(
          foregroundColor: MaterialInk.foreground(context, tone),
          disabledForegroundColor: disabledForeground,
        );
        return _withTonedSide(base, context, tone, disabledContainer);
      case _ButtonFamily.text:
        // `link` resolves its tone to `primary` and `quiet` resolves
        // `Tone.neutral` to `onSurface` (BTN-006), which is what keeps the
        // chrome-less button from reading as a link. One expression says both
        // because the tone already carries the difference.
        return TextButton.styleFrom(
          foregroundColor: MaterialInk.foreground(context, tone),
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  /// The colours an [Emphasis] and a [Tone] mean on a mark-only button.
  static ButtonStyle _iconButtonPaint(
    BuildContext context,
    Emphasis emphasis,
    Tone tone,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color disabledForeground = _disabledForeground(colors);
    final Color disabledContainer = _disabledContainer(colors);

    switch (_familyOf(emphasis)) {
      case _ButtonFamily.filled:
        final Color container = MaterialInk.foreground(context, tone);
        return IconButton.styleFrom(
          backgroundColor: container,
          foregroundColor: _onFilled(colors, tone, container),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case _ButtonFamily.outlined:
        final ButtonStyle base = IconButton.styleFrom(
          foregroundColor: tone == Tone.accent
              // The stock outlined icon button's glyph, which is
              // `onSurfaceVariant` and NOT `primary`: a mark-only control has
              // no label, so the accent would be the loudest thing in a
              // toolbar rather than the second loudest.
              ? colors.onSurfaceVariant
              : MaterialInk.foreground(context, tone),
          disabledForegroundColor: disabledForeground,
        );
        return _withTonedSide(base, context, tone, disabledContainer);
      case _ButtonFamily.text:
        // The stock standard icon button: chrome-less, `onSurfaceVariant`.
        // Both `quiet` and `link` collapse onto it for the same reason the
        // outlined one does not take the accent.
        return IconButton.styleFrom(
          foregroundColor: tone == Tone.accent || tone == Tone.neutral
              ? colors.onSurfaceVariant
              : MaterialInk.foreground(context, tone),
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  /// The foreground for text and marks painted on a filled [tone].
  ///
  /// Material pairs an on-colour with each of its own roles, so `accent` and
  /// `danger` take theirs from the scheme; every other tone is a colour this
  /// skin chose from its own palette and has no pair, so the contrast rule
  /// decides. That is what makes a success button legible whichever green the
  /// brightness resolved.
  static Color _onFilled(ColorScheme colors, Tone tone, Color container) {
    if (tone == Tone.accent) return colors.onPrimary;
    if (tone == Tone.danger) return colors.onError;
    return MaterialInk.foregroundOn(container);
  }

  /// [base] with an outline that carries [tone], where the M3 default cannot.
  ///
  /// `Tone.accent` deliberately gets NO side: the M3 default already does the
  /// right thing per state - `outline` enabled, `primary` focused, `onSurface`
  /// at 12 % disabled - and pinning it would freeze all three. Every other
  /// tone has to be stated, and states the disabled case with it so the
  /// semantic tint never survives into disabled.
  static ButtonStyle _withTonedSide(
    ButtonStyle base,
    BuildContext context,
    Tone tone,
    Color disabledContainer,
  ) {
    if (tone == Tone.accent) return base;
    final Color side = MaterialInk.foreground(context, tone);
    return base.copyWith(
      side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: disabledContainer);
        }
        return BorderSide(color: side);
      }),
    );
  }

  /// The button's content, moved out of `BaseButton._content`.
  ///
  /// The text carries no style and the marks carry no size or colour: the
  /// button style's `DefaultTextStyle` and `IconTheme` supply them, so label,
  /// spinner and both marks always match the resolved foreground.
  static Widget _buttonContent(
    BuildContext context,
    ButtonSpec spec,
    double glyphSize,
  ) {
    final Widget labelText = Text(spec.label);
    final bool hasTrailing = spec.trailing != null && !spec.isLoading;
    if (!spec.isLoading && spec.leading == null && !hasTrailing) {
      return labelText;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: MaterialMetrics.spaceS,
      children: <Widget>[
        if (spec.isLoading)
          SizedBox(
            width: glyphSize,
            height: glyphSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // While loading the button is disabled, so the spinner paints in
              // the M3 disabled foreground like the rest of the content.
              valueColor: AlwaysStoppedAnimation<Color>(
                _disabledForeground(Theme.of(context).colorScheme),
              ),
            ),
          )
        else if (spec.leading != null)
          Icon(MaterialGlyphs.of(spec.leading!)),
        labelText,
        if (hasTrailing) Icon(MaterialGlyphs.of(spec.trailing!)),
      ],
    );
  }

  /// A switch's colours, resolved per state.
  ///
  /// Moved verbatim from `BaseSwitch._resolvePerState`, and the record of the
  /// defect it fixed: the active colour only while selected, the inactive one
  /// otherwise, the disabled state resolving to null so the theme's disabled
  /// treatment stays intact, and no property at all when neither colour is
  /// given so the theme keeps full control.
  static WidgetStateProperty<Color?>? _perState(
    Color? active,
    Color? inactive,
  ) {
    if (active == null && inactive == null) return null;
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return null;
      return states.contains(WidgetState.selected) ? active : inactive;
    });
  }

  // ---------------------------------------------------------------------
  // The chip parts, moved out of `base_filter_chip.dart`.
  // ---------------------------------------------------------------------

  /// The M3 chip shape shared by every chip this skin draws: the 8 dp corner
  /// the token database gives all three chip classes, which is also this
  /// skin's control corner for buttons (BTN-001) and the `chipRadius` the
  /// theme is configured from.
  static final RoundedRectangleBorder _chipShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
  );

  /// The M3 chip glyph size, which like the button's 18 is Material's own
  /// number for the part rather than a rung of the icon scale.
  static const double _chipGlyphSize = 18;

  /// The mark size in one row of a dropdown's list, kept exactly as the
  /// application's `BaseDropdownItem` had it.
  static const double _dropdownRowGlyphSize = 14;

  /// The leading mark of a chip. Its colour is left to the chip's own icon
  /// theme, so selected and unselected resolve exactly as M3 specifies.
  static Widget? _chipAvatar(IconRole? role) =>
      role == null ? null : Icon(MaterialGlyphs.of(role), size: _chipGlyphSize);

  /// The label of a chip, as a plain `Text`.
  ///
  /// A chip owns its label typography: it wraps the label in a
  /// `DefaultTextStyle` built from the resolved chip label style, which is
  /// `labelLarge` in the role the chip's state calls for -
  /// `onSecondaryContainer` while selected, `onSurfaceVariant` otherwise.
  /// Giving the text a role and a colour of its own would replace that and
  /// silently drop the per-state pairing, which is the one thing a chip label
  /// must not lose.
  static Widget _chipLabel(String text) => Text(text);

  /// [child] under [message], or [child] alone when there is nothing to say.
  ///
  /// A group whose segments are `Aa`, `*` and `.*` is unreadable without it,
  /// and a tooltip on a symbol-only control is not optional here.
  static Widget _tooltipped(String? message, Widget child) =>
      message == null ? child : Tooltip(message: message, child: child);

  /// One row of a dropdown's list, moved out of `BaseDropdownItem.simple`.
  static Widget _optionRow<T>(BuildContext context, DropdownOption<T> option) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        if (option.icon != null) ...<Widget>[
          // 14, and it is off this skin's icon scale. It is the number the
          // application's dropdown row already used, and rounding it onto the
          // nearest rung would be a visible change - so it is kept as it is
          // and named as a thing to decide deliberately rather than on the way
          // past.
          Icon(MaterialGlyphs.of(option.icon!), size: _dropdownRowGlyphSize),
          const SizedBox(width: MaterialMetrics.spaceS),
        ],
        Expanded(
          child: Text(
            option.label,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge,
          ),
        ),
        if (option.detail != null) ...<Widget>[
          const SizedBox(width: MaterialMetrics.spaceS),
          Text(
            option.detail!,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  /// The mark colour that reads on a chosen swatch.
  ///
  /// The perceptual rule `project_dialog.dart` used, kept rather than folded
  /// into `MaterialInk.foregroundOn`. The application ships TWO contrast rules
  /// today - that one at a 0.5 threshold over `0.299R + 0.587G + 0.114B`, and
  /// `GitSemanticColors.foregroundOn` at a 0.179 threshold over the sRGB
  /// relative luminance - and they disagree, first on the blue at index 0.
  /// Reconciling them changes what a user sees, so it is a decision for this
  /// skin's owner to take deliberately rather than something an extraction may
  /// take on the way past.
  static Color _swatchForeground(Color swatch) {
    final double luminance =
        (0.299 * ((swatch.r * 255.0).round() & 0xff) +
            0.587 * ((swatch.g * 255.0).round() & 0xff) +
            0.114 * ((swatch.b * 255.0).round() & 0xff)) /
        255;
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }
}

/// The Material button families an [Emphasis] maps onto.
///
/// Filled is `FilledButton` / `IconButton.filled`, outlined is
/// `OutlinedButton` / `IconButton.outlined`, text is `TextButton` / the
/// standard `IconButton`.
enum _ButtonFamily { filled, outlined, text }

/// The decoration every field in this skin wears, in one place.
///
/// **The states are not spelled out, and that is the point.** The decoration
/// decides the border SHAPE per purpose; the SIDE - its colour and width in
/// every state: enabled, hovered, focused, error and disabled - is resolved by
/// `InputDecorator` from the Material 3 defaults
/// (`_InputDecoratorDefaultsM3.outlineBorder`), which it does for any border
/// whose side is not `BorderSide.none`. Hand-writing `enabledBorder`,
/// `errorBorder` and `disabledBorder` is what used to freeze the field at one
/// colour per state: it painted the error outline at the 2 dp weight M3
/// reserves for focus, the disabled outline at `outline` 38 % instead of
/// `onSurface` 12 %, and dropped the hover indication altogether, because a
/// spelled-out `enabledBorder` also wins in the hovered state.
///
/// The one purpose that has to spell anything out is the search field, and
/// only because it must: Material draws it as a filled box with no active
/// indicator (FIELD-003) and all four corners rounded (FIELD-002), and a
/// border with `BorderSide.none` makes `InputDecorator` return it unchanged
/// for EVERY state. So the states that must stay visible are written there,
/// and only those.
InputDecoration _fieldDecoration(
  BuildContext context, {
  required FieldPurpose purpose,
  String? label,
  String? hint,
  String? helper,
  String? error,
  Widget? prefix,
  Widget? suffix,
}) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  final OutlineInputBorder outlinedShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
  );
  final OutlineInputBorder filledShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
    borderSide: BorderSide.none,
  );

  final InputDecoration common = InputDecoration(
    // An empty label is treated as no label rather than as a label with no
    // words: the contract makes `FieldSpec.label` required so that every field
    // has an accessible name, and a search box inside an overlay names itself
    // with its hint instead of floating an empty box above itself.
    labelText: (label == null || label.isEmpty) ? null : label,
    hintText: hint,
    helperText: helper,
    errorText: error,
    prefixIcon: prefix,
    suffixIcon: suffix,
  );

  return switch (purpose) {
    FieldPurpose.text ||
    FieldPurpose.password => common.copyWith(border: outlinedShape),
    FieldPurpose.search => common.copyWith(
      filled: true,
      border: filledShape,
      disabledBorder: filledShape,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
    ),
  };
}

/// Material's answer to "what is the application asking the user to type?".
///
/// `_BaseTextFieldState`, moved: the controller ownership, the Escape ladder,
/// the double-click select-all and the in-field affordance, none of which is
/// appearance and all of which a skin has to keep because the application can
/// no longer see the field.
class _MaterialTextField extends StatefulWidget {
  const _MaterialTextField({required this.spec, required this.handles});

  final FieldSpec spec;
  final FieldHandles handles;

  @override
  State<_MaterialTextField> createState() => _MaterialTextFieldState();
}

class _MaterialTextFieldState extends State<_MaterialTextField> {
  late TextEditingController _controller;

  /// Whether [_controller] was created here rather than handed in.
  ///
  /// Ownership has to be tracked separately from `handles.controller == null`:
  /// a caller that swaps a controller in later leaves this state holding an
  /// internally created controller that `handles.controller == null` no longer
  /// describes, and disposing on that test alone would leak the one we made
  /// (or, the other way round, dispose one the caller still uses).
  bool _ownsController = false;

  /// Whether the user has asked to see a hidden answer.
  bool _revealed = false;

  /// Whether the field currently holds anything, which is what decides that a
  /// clear affordance is worth drawing.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _adoptController();
  }

  @override
  void didUpdateWidget(_MaterialTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.handles.controller != oldWidget.handles.controller) {
      // What the field currently shows, captured before the old controller is
      // released. It survives only into an internally created replacement: a
      // caller who hands us a controller is handing us its text too, and
      // overwriting that would be the field second-guessing its owner.
      final String carriedText = _controller.text;
      _releaseController();
      _adoptController(carriedText: carriedText);
    }
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  /// Takes the caller's controller, or creates one and remembers that this
  /// state owns it.
  ///
  /// [carriedText] is what the field was showing a moment ago, passed only
  /// when replacing one controller with another. An internally created
  /// replacement continues from it rather than from the handles' initial
  /// value: a caller who stops supplying a controller is changing who owns the
  /// text, not asking for the user's typing to be thrown away. On the first
  /// build there is nothing to carry, so the seed is the starting text.
  void _adoptController({String? carriedText}) {
    _ownsController = widget.handles.controller == null;
    _controller =
        widget.handles.controller ??
        TextEditingController(text: carriedText ?? widget.handles.startingText);
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  /// Detaches from the current controller, disposing it only when this state
  /// created it.
  void _releaseController() {
    _controller.removeListener(_handleTextChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleTextChanged() {
    final bool hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  /// Empties the field and tells the application, which is also what tells the
  /// hosting form.
  void _clear() {
    _controller.clear();
    widget.spec.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final FieldSpec spec = widget.spec;
    // A hidden answer is a single line by definition, and the SDK asserts as
    // much. Stating it here rather than letting the assert fire keeps a
    // password field with a stale `maxLines` rendering instead of crashing.
    final bool obscure = spec.purpose == FieldPurpose.password && !_revealed;

    return GestureDetector(
      onDoubleTap: () {
        // Select all text on double click.
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
      // Escape in a filled field clears it and keeps focus there - correcting
      // a typo must not throw the keyboard out of the field. An empty field
      // ignores the key, so it bubbles on to the innermost enclosing dismiss
      // scope (close the dialog, collapse the search, leave the mode): this is
      // the "clear the text" rung of the Escape ladder. The watcher node never
      // takes focus and is not a Tab stop.
      child: Focus(
        debugLabel: 'BaseTextField.escapeToClear',
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (!spec.escapeClears) return KeyEventResult.ignored;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey != LogicalKeyboardKey.escape) {
            return KeyEventResult.ignored;
          }
          if (_controller.text.isEmpty) return KeyEventResult.ignored;
          _clear();
          return KeyEventResult.handled;
        },
        child: TextField(
          controller: _controller,
          focusNode: widget.handles.focusNode,
          decoration: _fieldDecoration(
            context,
            purpose: spec.purpose,
            label: spec.label,
            hint: spec.hint,
            helper: spec.helper,
            error: spec.error,
            prefix: spec.leading == null
                ? null
                : Icon(
                    MaterialGlyphs.of(spec.leading!),
                    size: MaterialMetrics.iconM,
                  ),
            suffix: _affordance(context, spec),
          ),
          obscureText: obscure,
          maxLines: obscure ? 1 : spec.maxLines,
          onChanged: spec.onChanged,
          onSubmitted: spec.onSubmitted,
          autofocus: spec.autofocus,
          enabled: spec.enabled,
          enableInteractiveSelection: spec.selectable,
          // No `style`: the Material 3 input text role is `bodyLarge` and the
          // SDK also derives the disabled treatment from it - `bodyLarge` at
          // 38 % opacity. Overriding the style with `bodyMedium` shrank the
          // text a user types to the size of supporting text and replaced that
          // disabled treatment with a flat colour.
          //
          // That role carries its COLOUR too: the SDK reads
          // `textTheme.bodyLarge.color` and nothing else. It used to be the
          // light `onSurface` baked into the Google Fonts base theme, so a
          // dark-mode field painted the value at 1.17 : 1 - the third finding
          // of #402. The fix belongs in the type scale rather than here,
          // precisely so this field keeps deriving both the colour and the
          // disabled treatment from one role instead of pinning either.
        ),
      ),
    );
  }

  /// The action that belongs to this field, drawn INSIDE it.
  ///
  /// A sealed set of three rather than an icon and a callback, because that is
  /// what lets a language reach for its own affordance where it has one. An
  /// action belonging to a field is a trailing affordance in the field, never
  /// a free-floating button beside or below it - which is what the sealed set
  /// makes unsayable rather than merely discouraged.
  Widget? _affordance(BuildContext context, FieldSpec spec) {
    final MaterialLocalizations words = MaterialLocalizations.of(context);
    return switch (spec.suffix) {
      null => null,
      // The clear mark appears only while there is something to clear, which
      // is what `_hasText` is tracked for.
      FieldClearAffordance() =>
        !_hasText
            ? null
            : _affordanceButton(
                icon: IconRole.x,
                tooltip: words.clearButtonTooltip,
                onPressed: spec.enabled ? _clear : null,
              ),
      FieldRevealAffordance() => _affordanceButton(
        icon: _revealed ? IconRole.eyeSlash : IconRole.eye,
        // The one word this skin cannot take from `MaterialLocalizations`:
        // Material ships no string for revealing a secret. Named honestly in
        // English here rather than shipped as an untranslated string the
        // application would have to own, and the moment the contract grows a
        // way for a caller to name it, it comes from there.
        tooltip: _revealed ? 'Hide' : 'Show',
        onPressed: spec.enabled
            ? () => setState(() => _revealed = !_revealed)
            : null,
      ),
      FieldActionAffordance(
        :final IconRole icon,
        :final String tooltip,
        :final VoidCallback? onPressed,
      ) =>
        _affordanceButton(
          icon: icon,
          tooltip: tooltip,
          // A disabled field disables its action too, and an action with no
          // handler stays visible but inert, so the field does not change
          // shape as the action becomes available.
          onPressed: spec.enabled ? onPressed : null,
        ),
    };
  }

  /// One in-field action, at the size a field's trailing slot allows.
  Widget _affordanceButton({
    required IconRole icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => const MaterialControls().iconButton(
    context,
    IconButtonSpec(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      scale: ControlScale.compact,
    ),
  );
}

/// Material's answer to "which moment is the application asking the user to
/// name?".
class _MaterialDateField extends StatefulWidget {
  const _MaterialDateField({required this.spec, required this.handles});

  final DateFieldSpec spec;
  final FieldHandles handles;

  @override
  State<_MaterialDateField> createState() => _MaterialDateFieldState();
}

class _MaterialDateFieldState extends State<_MaterialDateField> {
  bool _isFocused = false;
  bool _isHovering = false;

  /// The one date format that is not a locale decision, and the one the
  /// application already renders.
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// The same, plus the time of day, for `DatePrecision.dateTime`.
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final DateFieldSpec spec = widget.spec;
    final MaterialLocalizations words = MaterialLocalizations.of(context);
    final DateTime? value = spec.value;

    // Hover is tracked with a `MouseRegion` and focus with `onFocusChange`
    // rather than with `FocusableActionDetector`'s two highlight callbacks:
    // those are gated on the focus HIGHLIGHT MODE and stay silent while the
    // app is in touch mode, whereas a text field shows its focused outline
    // however it was reached - including by a mouse click - and darkens its
    // outline whenever the pointer is over it.
    return MouseRegion(
      cursor: spec.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (PointerEnterEvent event) => setState(() => _isHovering = true),
      onExit: (PointerExitEvent event) => setState(() => _isHovering = false),
      child: FocusableActionDetector(
        enabled: spec.enabled,
        focusNode: widget.handles.focusNode,
        onFocusChange: (bool focused) => setState(() => _isFocused = focused),
        // Enter and Space must open the picker: the field is a Tab stop, and a
        // control a keyboard user can reach but not operate is an unfinished
        // control. Both intents are bound because the framework's default
        // shortcuts send `ActivateIntent` for Space and `ButtonActivateIntent`
        // for Enter on some platforms.
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) => _pick(context),
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) => _pick(context),
          ),
        },
        child: GestureDetector(
          onTap: spec.enabled ? () => _pick(context) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: spec.label,
              // The empty field shows the M3 hint, not a value-styled
              // placeholder: "no date yet" is not a value.
              hintText: spec.hint ?? words.datePickerHelpText,
              border: const OutlineInputBorder(),
              enabled: spec.enabled,
              suffixIcon: value != null
                  ? const MaterialControls().iconButton(
                      context,
                      IconButtonSpec(
                        icon: IconRole.x,
                        tooltip: words.clearButtonTooltip,
                        onPressed: spec.enabled
                            ? () => spec.onChanged(null)
                            : null,
                        scale: ControlScale.compact,
                      ),
                    )
                  : Icon(
                      MaterialGlyphs.of(IconRole.calendar),
                      size: MaterialMetrics.iconM,
                    ),
            ),
            isEmpty: value == null,
            isFocused: _isFocused,
            isHovering: _isHovering,
            // The value slot always carries a line of input-role text, empty
            // or not, so the field keeps one height whether or not a moment is
            // named.
            child: Text(
              value == null ? '' : _format(spec.precision).format(value),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  /// How much of the moment is written out.
  DateFormat _format(DatePrecision precision) => switch (precision) {
    DatePrecision.date => _dateFormat,
    DatePrecision.dateTime => _dateTimeFormat,
  };

  /// Asks for a moment with Material's own pickers.
  ///
  /// `DatePrecision.dateTime` asks twice, because Material has no single
  /// picker for both and composing the two is what every Material application
  /// does. A user who leaves the second picker keeps the day they named, which
  /// is the answer that loses least.
  Future<void> _pick(BuildContext context) async {
    final DateFieldSpec spec = widget.spec;
    final DateTime? day = await showThemedDatePicker(
      context: context,
      initialDate: spec.value ?? DateTime.now(),
      firstDate: spec.first ?? DateTime(2000),
      lastDate: spec.last ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (day == null) return;
    if (spec.precision == DatePrecision.date) {
      spec.onChanged(day);
      return;
    }
    if (!context.mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(spec.value ?? day),
    );
    spec.onChanged(
      DateTime(
        day.year,
        day.month,
        day.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
    );
  }
}

/// Shows the SDK date picker under this skin's own theme, with the picker's
/// text and label colours stated explicitly so both brightnesses read
/// correctly.
///
/// Moved from `base_date_field.dart`. Every override it applies is LAYERED
/// ONTO what the theme already configured rather than substituted for it:
/// `ThemeData.copyWith` and `TextTheme.copyWith` both replace the slot they
/// are handed, so a freshly built `InputDecorationTheme` - or a bare
/// `TextStyle(color: ...)` in a text role - discards the input decorator's
/// corner radius, its fill, the body-sized label and hint, and the family,
/// size, tracking and line height of the two body roles. The picker's
/// manual-entry field then renders on the framework defaults for anything not
/// spelled out inline, which is the defect #400 records - the same one #399
/// fixed a level up, in the button sub-themes.
Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (BuildContext context, Widget? child) {
      final ThemeData theme = Theme.of(context);
      final ColorScheme colors = theme.colorScheme;
      final InputDecorationThemeData inputTheme = theme.inputDecorationTheme;
      final TextTheme textTheme = theme.textTheme;

      return Theme(
        data: theme.copyWith(
          inputDecorationTheme: inputTheme.copyWith(
            labelStyle: _withColor(inputTheme.labelStyle, colors.onSurface),
            hintStyle: _withColor(
              inputTheme.hintStyle,
              colors.onSurfaceVariant,
            ),
            floatingLabelStyle: _withColor(
              inputTheme.floatingLabelStyle,
              colors.primary,
            ),
          ),
          textTheme: textTheme.copyWith(
            bodyLarge: _withColor(textTheme.bodyLarge, colors.onSurface),
            bodyMedium: _withColor(textTheme.bodyMedium, colors.onSurface),
          ),
        ),
        child: child!,
      );
    },
  );
}

/// [base] recoloured to [color], keeping every other property it carries.
///
/// The bare fallback applies only where the theme configured nothing at all -
/// the one case in which there is no configuration left to preserve.
TextStyle _withColor(TextStyle? base, Color color) =>
    base?.copyWith(color: color) ?? TextStyle(color: color);

/// Material's answer to "which item of a closed list is the user narrowing
/// towards?".
///
/// `SearchableBaseDropdown`, moved. The list lives in an `OverlayEntry`
/// anchored to the field with a `LayerLink`, which is what lets it escape the
/// dialog's own clip.
class _MaterialSuggestField<T> extends StatefulWidget {
  const _MaterialSuggestField({required this.spec, required this.handles});

  final SuggestFieldSpec<T> spec;
  final FieldHandles handles;

  @override
  State<_MaterialSuggestField<T>> createState() =>
      _MaterialSuggestFieldState<T>();
}

class _MaterialSuggestFieldState<T> extends State<_MaterialSuggestField<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggleOverlay() {
    if (_overlay != null) {
      setState(_removeOverlay);
      return;
    }
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Size size = box.size;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + MaterialMetrics.spaceXS),
          child: Material(
            elevation: MaterialMetrics.elevationRaised,
            borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
            child: _MaterialSuggestOverlay<T>(
              spec: widget.spec,
              onSelected: (T value) {
                widget.spec.onSelected(value);
                setState(_removeOverlay);
              },
              onDismiss: () => setState(_removeOverlay),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    // The rebuild is only so the caret turns over: the list itself lives in
    // the overlay and is already on screen by the time this runs.
    setState(() => _overlay = entry);
  }

  /// What the current value is called, or the hint while there is none.
  String get _shown {
    for (final SuggestItem<T> item in widget.spec.items) {
      if (item.value == widget.spec.value) return item.label;
    }
    return widget.spec.hint ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final SuggestFieldSpec<T> spec = widget.spec;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isOpen = _overlay != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (spec.label.isNotEmpty) ...<Widget>[
            Text(spec.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: MaterialMetrics.spaceXS),
          ],
          InkWell(
            onTap: spec.enabled ? _toggleOverlay : null,
            focusNode: widget.handles.focusNode,
            borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MaterialMetrics.spaceM,
                vertical: MaterialMetrics.spaceS + 4,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _shown,
                      overflow: TextOverflow.ellipsis,
                      // The hint is muted and a settled value is not, and the
                      // two are separate styles rather than one style
                      // recoloured with a null: a `copyWith(color: null)`
                      // keeps whatever colour was already there, which reads
                      // as a decision and is not one.
                      style: spec.value == null
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    MaterialGlyphs.of(
                      isOpen ? IconRole.caretUp : IconRole.caretDown,
                    ),
                    size: MaterialMetrics.iconS,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the suggest field's overlay holds: a search box, a rule and the
/// matches.
class _MaterialSuggestOverlay<T> extends StatefulWidget {
  const _MaterialSuggestOverlay({
    required this.spec,
    required this.onSelected,
    required this.onDismiss,
  });

  final SuggestFieldSpec<T> spec;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  @override
  State<_MaterialSuggestOverlay<T>> createState() =>
      _MaterialSuggestOverlayState<T>();
}

class _MaterialSuggestOverlayState<T>
    extends State<_MaterialSuggestOverlay<T>> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  /// How tall the list may grow before it scrolls.
  static const double _maxListExtent = 300;

  @override
  void initState() {
    super.initState();
    // The keyboard lands in the search box the moment the overlay opens: a
    // control the user just opened in order to type in is not one they should
    // have to click first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  /// The suggestions the query allows, or all of them while the query is too
  /// short to be worth narrowing from.
  List<SuggestItem<T>> get _matches {
    final String needle = _query.text.trim().toLowerCase();
    if (needle.length < widget.spec.minQueryLength) return widget.spec.items;
    return widget.spec.items
        .where(
          (SuggestItem<T> item) => item.label.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final SuggestFieldSpec<T> spec = widget.spec;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<SuggestItem<T>> matches = _matches;

    return TapRegion(
      onTapOutside: (PointerDownEvent event) => widget.onDismiss(),
      child: Container(
        constraints: const BoxConstraints(maxHeight: _maxListExtent),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
          border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(MaterialMetrics.spaceS),
              child: const MaterialControls().textField(
                context,
                FieldSpec(
                  // No label: the box names itself with its hint, and a
                  // floating label above a search box inside an overlay would
                  // cost a line of height for a word the user just read on the
                  // control they opened.
                  label: '',
                  purpose: FieldPurpose.search,
                  hint:
                      spec.hint ??
                      MaterialLocalizations.of(context).searchFieldLabel,
                  leading: IconRole.magnifyingGlass,
                  onChanged: (String value) {
                    setState(() {});
                    spec.onQueryChanged?.call(value);
                  },
                ),
                FieldHandles(controller: _query, focusNode: _queryFocus),
              ),
            ),
            Divider(height: 1, color: colors.outline.withValues(alpha: 0.3)),
            Flexible(
              child: matches.isEmpty
                  ? _emptyNotice(context, spec)
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      itemBuilder: (BuildContext context, int index) {
                        final SuggestItem<T> item = matches[index];
                        return InkWell(
                          onTap: () => widget.onSelected(item.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MaterialMetrics.spaceM,
                              vertical: MaterialMetrics.spaceS,
                            ),
                            child: _itemRow(context, item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// What to show when nothing matches.
  ///
  /// The application used to hard-code an English "No items found" here. The
  /// contract gives the caller a slot for those words instead, so a null
  /// `emptyLabel` means the application chose to say nothing - and this skin
  /// says nothing rather than shipping an untranslated sentence of its own.
  Widget _emptyNotice(BuildContext context, SuggestFieldSpec<T> spec) {
    if (spec.emptyLabel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(MaterialMetrics.spaceL),
      child: Center(
        child: Text(
          spec.emptyLabel!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// One suggestion: its mark, its name and what distinguishes it.
  Widget _itemRow(BuildContext context, SuggestItem<T> item) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        if (item.icon != null) ...<Widget>[
          Icon(MaterialGlyphs.of(item.icon!), size: MaterialMetrics.iconS),
          const SizedBox(width: MaterialMetrics.spaceS),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              if (item.detail != null)
                Text(
                  item.detail!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
