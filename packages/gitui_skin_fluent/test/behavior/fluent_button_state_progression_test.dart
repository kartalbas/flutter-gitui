/// REST -> HOVER -> PRESSED, measured from the paint stream.
///
/// This is behaviour 1 of the Fluent behaviour suite: what changes between
/// the three pointer states, by how much, and - above all - in which
/// DIRECTION. Fluent's standard control DARKENS as it is pressed, because
/// its translucent fill loses opacity over the ground
/// (`ControlFillColorDefault` -> `Secondary` -> `Tertiary`); Material's
/// filled button LIGHTENS, because it lays a white state layer over its
/// fill (`onPrimary` at 8%/10%, md.comp.filled-button tokens). A
/// reimplementation that gets the magnitude right and the direction wrong
/// still feels wrong, which is why every directional claim here is asserted
/// on the COMPOSITE over the language's own page ground and not on the raw
/// resource.
///
/// Every pinned literal restates its source beside it, independently of the
/// constants in lib/, so a drive-by edit to `fluent_resources.dart` fails
/// here instead of passing silently.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';
import 'package:gitui_skin_fluent/src/fluent_theme.dart';

import 'support/fluent_behavior_harness.dart';

// ---------------------------------------------------------------------------
// Pinned WinUI resources (fluent_ui@4.16.1 lib/src/styles/color_resources.dart
// unless noted; resource names from microsoft-ui-xaml
// Common_themeresources_any.xaml).
// ---------------------------------------------------------------------------

// SolidBackgroundFillColorBase: light :340, dark :253.
const Color _groundLight = Color(0xFFf3f3f3);
const Color _groundDark = Color(0xFF202020);

// ControlFillColorDefault / Secondary (hover) / Tertiary (pressed), light
// theme: :287, :288, :289.
const Color _standardRestLight = Color(0xb3ffffff);
const Color _standardHoverLight = Color(0x80f9f9f9);
const Color _standardPressedLight = Color(0x4df9f9f9);

// The same three resources, dark theme: :200, :201, :202.
const Color _standardRestDark = Color(0x0fffffff);
const Color _standardHoverDark = Color(0x15ffffff);
const Color _standardPressedDark = Color(0x08ffffff);

// TextFillColorPrimary / Secondary, light theme: :277, :278.
const Color _labelRestLight = Color(0xe4000000);
const Color _labelPressedLight = Color(0x9e000000);

// ControlStrokeColorDefault, light theme: :311.
const Color _strokeDefaultLight = Color(0x0f000000);

// The Windows default accent swatch's dark and lighter stops
// (fluent_ui@4.16.1 lib/src/styles/color.dart:171 and :174), which are the
// RESTING accent fills: light themes rest on `dark`, dark themes on
// `lighter` (color.dart:347-352, AccentFillColorDefaultBrush).
const Color _accentRestLight = Color(0xff0066b4);
const Color _accentRestDark = Color(0xff4ca0e0);

// TextOnAccentFillColorPrimary / Secondary, light theme: :284, :285.
const Color _onAccentRestLight = Color(0xFFffffff);
const Color _onAccentPressedLight = Color(0xb3ffffff);

ButtonSpec _spec(Emphasis emphasis, VoidCallback onPressed) =>
    ButtonSpec(label: 'Probe', emphasis: emphasis, onPressed: onPressed);

Widget _button(Emphasis emphasis) => FluentButton(spec: _spec(emphasis, () {}));

void main() {
  group('standard button, light', () {
    testWidgets('rests on ControlFillColorDefault', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      expect(containerFill(tester).toARGB32(), _standardRestLight.toARGB32());
    });

    testWidgets('hover moves the fill to ControlFillColorSecondary and '
        'DARKENS the composite', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      final double restLuminance = luminanceOver(
        _groundLight,
        containerFill(tester),
      );
      await hoverOver(tester, find.byType(FluentButton));
      final Color hovered = containerFill(tester);
      expect(hovered.toARGB32(), _standardHoverLight.toARGB32());
      expect(
        luminanceOver(_groundLight, hovered),
        lessThan(restLuminance),
        reason:
            'on the light ground the hover fill must read DARKER than '
            'rest: the resource ladder drops the white fill\'s opacity '
            '(0xb3 -> 0x80, color_resources.dart:287-288), letting more '
            'of the darker ground through',
      );
    });

    testWidgets('press moves the fill to ControlFillColorTertiary, the '
        'darkest of the three - where Material lightens', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      final double restLuminance = luminanceOver(
        _groundLight,
        containerFill(tester),
      );
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      final Color pressed = containerFill(tester);
      expect(pressed.toARGB32(), _standardPressedLight.toARGB32());
      final double pressedLuminance = luminanceOver(_groundLight, pressed);
      expect(
        pressedLuminance,
        lessThan(restLuminance),
        reason:
            'pressing a Fluent standard control must DARKEN it below rest '
            '(opacity ladder 0xb3 -> 0x4d, color_resources.dart:287-289). '
            'Material moves the other way - its pressed state lays '
            'onPrimary white at 10% OVER the fill - and getting this '
            'direction wrong is the classic reimplementation failure.',
      );
      expect(
        pressedLuminance,
        lessThan(luminanceOver(_groundLight, _standardHoverLight)),
        reason: 'pressed must also sit below hover, completing the ladder',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('press dims the label to TextFillColorSecondary', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        _labelRestLight.toARGB32(),
      );
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      // The label animates one step slower than its container
      // (fluent_ui buttons/base.dart:231-232, 167 ms); settle it fully.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        _labelPressedLight.toARGB32(),
        reason:
            'a pressed standard button writes in TextFillColorSecondary '
            '(fluent_ui buttons/theme.dart:312-323) - the words recede '
            'with the control',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the elevation stroke flattens on press', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      final List<PaintedOutline> resting = paintedOutlines(
        tester,
        buttonContainer(),
      );
      expect(resting, hasLength(1));
      expect(
        resting.single.hasShader,
        isTrue,
        reason:
            'at rest the outline is the gradient elevation stroke - '
            'darker along the bottom edge (fluent_ui '
            'buttons/theme.dart:337-349)',
      );
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      final List<PaintedOutline> pressed = paintedOutlines(
        tester,
        buttonContainer(),
      );
      expect(pressed, hasLength(1));
      expect(
        pressed.single.hasShader,
        isFalse,
        reason:
            'a pressed control drops the elevation stroke for a flat one '
            '(fluent_ui buttons/theme.dart:331-335) - half of why a '
            'Fluent press reads as the control being pushed in',
      );
      expect(
        pressed.single.color.toARGB32(),
        _strokeDefaultLight.toARGB32(),
        reason:
            'the flat stroke is ControlStrokeColorDefault '
            '(color_resources.dart:311)',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('standard button, dark', () {
    testWidgets('pins the dark resource ladder', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _button(Emphasis.secondary),
        brightness: Brightness.dark,
      );
      expect(containerFill(tester).toARGB32(), _standardRestDark.toARGB32());
      await hoverOver(tester, find.byType(FluentButton));
      expect(containerFill(tester).toARGB32(), _standardHoverDark.toARGB32());
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      expect(containerFill(tester).toARGB32(), _standardPressedDark.toARGB32());
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dark hover LIGHTENS, dark press still falls below rest', (
      WidgetTester tester,
    ) async {
      // The dark-theme signature: hover raises the white fill's opacity
      // (0x0f -> 0x15) and so lightens, while press drops it below rest
      // (0x08) - the press always lands darker than wherever the pointer
      // came from (color_resources.dart:200-202).
      await pumpFluentBehavior(
        tester,
        _button(Emphasis.secondary),
        brightness: Brightness.dark,
      );
      final double rest = luminanceOver(_groundDark, _standardRestDark);
      final double hover = luminanceOver(_groundDark, _standardHoverDark);
      final double pressed = luminanceOver(_groundDark, _standardPressedDark);
      expect(hover, greaterThan(rest));
      expect(pressed, lessThan(rest));
      expect(pressed, lessThan(hover));
      // And the pins above prove those are the fills actually painted.
    });
  });

  group('accent button, light', () {
    testWidgets('rests on the swatch\'s dark stop, dims by opacity through '
        'hover and press', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _button(Emphasis.primary));
      expect(containerFill(tester).toARGB32(), _accentRestLight.toARGB32());
      await hoverOver(tester, find.byType(FluentButton));
      expectPaintedColor(
        containerFill(tester),
        // AccentFillColorSecondaryBrush: the resting brush at Opacity 0.9
        // (microsoft-ui-xaml Common_themeresources_any.xaml L163-166;
        // fluent_ui color.dart:358-360).
        _accentRestLight.withValues(alpha: 0.9),
      );
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      expectPaintedColor(
        containerFill(tester),
        // AccentFillColorTertiaryBrush: Opacity 0.8 (same sources;
        // color.dart:366-368).
        _accentRestLight.withValues(alpha: 0.8),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the accent fill RECEDES toward the ground as it is '
        'pressed', (WidgetTester tester) async {
      // Direction, stated composably: dimming by opacity pulls the
      // composite toward the ground on EITHER brightness - press an accent
      // button and it fades, it never tints. Material's accent (filled)
      // button does the opposite: press lays a fresh overlay ON TOP.
      await pumpFluentBehavior(tester, _button(Emphasis.primary));
      final double groundLuminance = _groundLight.computeLuminance();
      double distance(Color fill) =>
          (luminanceOver(_groundLight, fill) - groundLuminance).abs();
      final double rest = distance(_accentRestLight);
      final double hover = distance(_accentRestLight.withValues(alpha: 0.9));
      final double pressed = distance(_accentRestLight.withValues(alpha: 0.8));
      expect(hover, lessThan(rest));
      expect(pressed, lessThan(hover));
    });

    testWidgets('press dims the on-accent label', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _button(Emphasis.primary));
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        _onAccentRestLight.toARGB32(),
      );
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        _onAccentPressedLight.toARGB32(),
        reason:
            'a pressed accent button writes in '
            'TextOnAccentFillColorSecondary (fluent_ui '
            'filled_button.dart:113-123; color_resources.dart:285)',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('accent button, dark', () {
    testWidgets('rests on the swatch\'s lighter stop and fades on press', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _button(Emphasis.primary),
        brightness: Brightness.dark,
      );
      expect(containerFill(tester).toARGB32(), _accentRestDark.toARGB32());
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(FluentButton),
      );
      expectPaintedColor(
        containerFill(tester),
        _accentRestDark.withValues(alpha: 0.8),
      );
      // Same fade direction over the dark ground: the pressed composite
      // sits closer to the ground than rest does.
      final double groundLuminance = _groundDark.computeLuminance();
      expect(
        (luminanceOver(_groundDark, _accentRestDark.withValues(alpha: 0.8)) -
                groundLuminance)
            .abs(),
        lessThan(
          (luminanceOver(_groundDark, _accentRestDark) - groundLuminance).abs(),
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('harness sanity', () {
    testWidgets('the theme scope is the harness\'s and not an app root\'s', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _button(Emphasis.secondary));
      final BuildContext context = tester.element(find.byType(FluentButton));
      expect(FluentTheme.of(context).brightness, Brightness.light);
    });
  });
}
