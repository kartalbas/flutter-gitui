import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_stroke_border.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_pressable.dart';

/// The Fluent answer to `SkinControls.button`: WHAT CAN THE USER DO HERE,
/// IN WORDS - drawn against WinUI, with no widget library underneath.
///
/// The four [Emphasis] values land on WinUI's four button treatments:
///
///  * [Emphasis.primary] - the accent ("filled") button;
///  * [Emphasis.secondary] - the standard button;
///  * [Emphasis.quiet] - the subtle button (no fill at rest, no outline);
///  * [Emphasis.link] - the hyperlink button (accent text, subtle fills).
///
/// Colour tables, borders and motion each carry their provenance at the
/// site. What this member does NOT yet honour, stated rather than hidden:
///
///  * **[ButtonSpec.tone]** beyond `accent`/`neutral`. Fluent has no
///    published treatment for a danger or success BUTTON fill - WinUI keeps
///    destructive actions in ordinary buttons and says the danger in words -
///    so rounding `Tone.danger` onto a red accent would be inventing. The
///    right mapping is a finding to settle against the Fluent 2 spec, not a
///    guess to ship.
///  * **[ButtonSpec.leading] / [ButtonSpec.trailing]**: an [IconRole]
///    resolves through a glyph table this skin does not have yet (the
///    Material skin's is 155 entries); the label renders alone until the
///    Fluent glyph decision is made.
///  * **[ButtonSpec.tooltip]**: a tooltip is an overlay surface, and this
///    skin has no overlay facet yet.
///  * **[ButtonSpec.isLoading]** disables the control and keeps its words;
///    the in-place progress presentation belongs to the progress member.
///  * **[ButtonSpec.scale]**: Fluent 2 has exactly one control height, the
///    contract's known collapse for this language (the spike measured
///    `size` as the only lossy `BaseButton` parameter under Fluent); all
///    three [ControlScale]s draw the same box.
final class FluentButton extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentButton({super.key, required this.spec});

  /// What the application declared.
  final ButtonSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final bool disabled = spec.isLoading || spec.onPressed == null;
    // Semantics per the reference button shell (buttons/base.dart:250-255).
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      child: FluentPressable(
        onPressed: disabled ? null : spec.onPressed,
        semanticsLabel: spec.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final _ButtonColors colors = _resolve(theme, spec.emphasis, states);
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              // The container answers a state change at the faster step on
              // the standard curve (buttons/base.dart:218-219).
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              decoration: ShapeDecoration(
                color: colors.fill,
                shape: colors.shape,
              ),
              padding: FluentGeometry.buttonPadding,
              child: IconTheme.merge(
                // Glyphs ride the foreground at 14 epx
                // (buttons/base.dart:226-230).
                data: IconThemeData(
                  color: colors.foreground,
                  size: FluentGeometry.buttonIconSize,
                ),
                child: AnimatedDefaultTextStyle(
                  // Text answers one step slower than its container
                  // (buttons/base.dart:231-232).
                  duration: FluentMotion.fast,
                  curve: FluentMotion.curve,
                  // A button label is body text in Fluent - no emboldening
                  // (buttons/base.dart:178) - resolved through the type
                  // facet's single door.
                  style: FluentTypeResolution.styleOf(
                    context,
                    TextRole.control,
                  ).copyWith(color: colors.foreground),
                  textAlign: TextAlign.center,
                  child: Center(
                    heightFactor: 1,
                    widthFactor: spec.fillWidth ? null : 1,
                    child: Text(spec.label),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One resolved appearance: what fills, what writes, what outlines.
final class _ButtonColors {
  const _ButtonColors({
    required this.fill,
    required this.foreground,
    required this.shape,
  });

  final Color fill;
  final Color foreground;
  final ShapeBorder shape;
}

BorderRadius get _corner =>
    BorderRadius.circular(FluentGeometry.controlCornerRadius);

_ButtonColors _resolve(
  FluentThemeData theme,
  Emphasis emphasis,
  Set<WidgetState> states,
) {
  return switch (emphasis) {
    Emphasis.primary => _accent(theme, states),
    Emphasis.secondary => _standard(theme, states),
    Emphasis.quiet => _subtle(theme, states),
    Emphasis.link => _hyperlink(theme, states),
  };
}

/// The accent button (fluent_ui@4.16.1 controls/buttons/filled_button.dart).
_ButtonColors _accent(FluentThemeData theme, Set<WidgetState> states) {
  final FluentResources res = theme.resources;
  final bool pressedOrDisabled =
      states.contains(WidgetState.pressed) ||
      states.contains(WidgetState.disabled);
  // Fill: filled_button.dart:100-110. Hover and press DIM the accent by
  // opacity - the fill recedes toward the ground instead of tinting.
  final Color fill = states.contains(WidgetState.disabled)
      ? res.accentFillColorDisabled
      : states.contains(WidgetState.pressed)
      ? theme.accent.tertiaryBrushFor(theme.brightness)
      : states.contains(WidgetState.hovered)
      ? theme.accent.secondaryBrushFor(theme.brightness)
      : theme.accent.defaultBrushFor(theme.brightness);
  // Foreground: filled_button.dart:113-123. The pressed label dims with its
  // fill.
  final Color foreground = states.contains(WidgetState.pressed)
      ? res.textOnAccentFillColorSecondary
      : states.contains(WidgetState.disabled)
      ? res.textOnAccentFillColorDisabled
      : res.textOnAccentFillColorPrimary;
  // Outline: the on-accent elevation stroke at rest and hover, flattening
  // to an explicit no-stroke when pressed or disabled
  // (filled_button.dart:126-150).
  final ShapeBorder shape = pressedOrDisabled
      ? FluentStrokeBorder.solid(
          color: res.controlFillColorTransparent,
          borderRadius: _corner,
        )
      : FluentStrokeBorder.gradient(
          // filled_button.dart:137-149: begin (0,-2) to bottomCenter,
          // [onAccentSecondary, onAccentDefault] at stops [0.33, 1.0],
          // rotated by pi - which lands the darker secondary run on the
          // bottom edge.
          gradient: LinearGradient(
            begin: const Alignment(0, -2),
            end: Alignment.bottomCenter,
            colors: <Color>[
              res.controlStrokeColorOnAccentSecondary,
              res.controlStrokeColorOnAccentDefault,
            ],
            stops: const <double>[0.33, 1.0],
            transform: const GradientRotation(math.pi),
          ),
          borderRadius: _corner,
        );
  return _ButtonColors(fill: fill, foreground: foreground, shape: shape);
}

/// The standard button (fluent_ui@4.16.1 controls/buttons/theme.dart).
_ButtonColors _standard(FluentThemeData theme, Set<WidgetState> states) {
  final FluentResources res = theme.resources;
  final bool pressedOrDisabled =
      states.contains(WidgetState.pressed) ||
      states.contains(WidgetState.disabled);
  // Fill: buttons/theme.dart:292-308 (`ButtonThemeData.buttonColor`). The
  // fill's opacity FALLS from rest through hover to pressed, so over the
  // ground the control darkens as it is pressed - the opposite direction
  // from Material's lightening overlay.
  final Color fill = states.contains(WidgetState.pressed)
      ? res.controlFillColorTertiary
      : states.contains(WidgetState.hovered)
      ? res.controlFillColorSecondary
      : states.contains(WidgetState.disabled)
      ? res.controlFillColorDisabled
      : res.controlFillColorDefault;
  // Foreground: buttons/theme.dart:312-323. The pressed label dims to the
  // secondary text colour.
  final Color foreground = states.contains(WidgetState.pressed)
      ? res.textFillColorSecondary
      : states.contains(WidgetState.disabled)
      ? res.textFillColorDisabled
      : res.textFillColorPrimary;
  // Outline: buttons/theme.dart:326-350. The elevation stroke - darker
  // along the bottom - at rest and hover; a flat default stroke when
  // pressed or disabled.
  final ShapeBorder shape = pressedOrDisabled
      ? FluentStrokeBorder.solid(
          color: res.controlStrokeColorDefault,
          borderRadius: _corner,
        )
      : FluentStrokeBorder.gradient(
          // buttons/theme.dart:337-349: centre to (0,3),
          // [controlStrokeColorSecondary, controlStrokeColorDefault] at
          // stops [0.3, 1.0].
          gradient: LinearGradient(
            begin: Alignment.center,
            end: const Alignment(0, 3),
            colors: <Color>[
              res.controlStrokeColorSecondary,
              res.controlStrokeColorDefault,
            ],
            stops: const <double>[0.3, 1.0],
          ),
          borderRadius: _corner,
        );
  return _ButtonColors(fill: fill, foreground: foreground, shape: shape);
}

/// The subtle button: no fill at rest, no outline ever. Fill table per the
/// subtle-fill resources (fluent_ui@4.16.1
/// controls/buttons/hyperlink_button.dart:93-105, the same
/// `SubtleFillColor*` ladder WinUI's subtle button reads); foreground per
/// the standard table (buttons/theme.dart:312-323).
_ButtonColors _subtle(FluentThemeData theme, Set<WidgetState> states) {
  final FluentResources res = theme.resources;
  final Color fill = states.contains(WidgetState.disabled)
      ? res.subtleFillColorDisabled
      : states.contains(WidgetState.pressed)
      ? res.subtleFillColorTertiary
      : states.contains(WidgetState.hovered)
      ? res.subtleFillColorSecondary
      : res.subtleFillColorTransparent;
  final Color foreground = states.contains(WidgetState.pressed)
      ? res.textFillColorSecondary
      : states.contains(WidgetState.disabled)
      ? res.textFillColorDisabled
      : res.textFillColorPrimary;
  return _ButtonColors(
    fill: fill,
    foreground: foreground,
    shape: RoundedRectangleBorder(borderRadius: _corner),
  );
}

/// The hyperlink button: subtle fills under accent-coloured words
/// (fluent_ui@4.16.1 controls/buttons/hyperlink_button.dart:69-105).
///
/// One divergence from the checkout, in the specification's favour: the
/// checkout's DISABLED foreground reads `controlFillColorDisabled`
/// (hyperlink_button.dart:70-72) - a translucent-white CONTROL fill, near
/// invisible as text on the light ground. WinUI's own resource for it is
/// `AccentTextFillColorDisabled` (HyperlinkButtonForegroundDisabled,
/// HyperlinkButton_themeresources.xaml), which is what is used here.
_ButtonColors _hyperlink(FluentThemeData theme, Set<WidgetState> states) {
  final FluentResources res = theme.resources;
  final Color fill = states.contains(WidgetState.disabled)
      ? res.subtleFillColorDisabled
      : states.contains(WidgetState.pressed)
      ? res.subtleFillColorTertiary
      : states.contains(WidgetState.hovered)
      ? res.subtleFillColorSecondary
      : res.subtleFillColorTransparent;
  final Color foreground = states.contains(WidgetState.disabled)
      ? res.accentTextFillColorDisabled
      : states.contains(WidgetState.pressed)
      ? theme.accent.tertiaryBrushFor(theme.brightness)
      : states.contains(WidgetState.hovered)
      ? theme.accent.secondaryBrushFor(theme.brightness)
      : theme.accent.defaultBrushFor(theme.brightness);
  return _ButtonColors(
    fill: fill,
    foreground: foreground,
    shape: RoundedRectangleBorder(borderRadius: _corner),
  );
}
