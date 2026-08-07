/// Material 3 conformance suite for BaseSwitch
/// (lib/shared/components/base_animated_widgets.dart).
///
/// ## Why the oracle is pinned rather than pumped
///
/// Every other suite in this directory measures the Base component against the
/// SDK widget it corresponds to, pumped through the same harness. That trick
/// only works while the app leaves the SDK widget's theme alone, and here it
/// does not: `AppTheme` builds on FlexColorScheme with `subThemesData`, which
/// installs a `switchTheme` of its own, so a stock `Switch` pumped under the
/// app's theme renders the *app's* switch and would report the app's values
/// back as if they were the specification. This is the same trap the dialog
/// suites documented for `dialogTheme`.
///
/// The ruler here is therefore the generated token block itself:
/// `_SwitchDefaultsM3` and `_SwitchConfigM3` in
/// `packages/flutter/lib/src/material/switch.dart` (Flutter 3.44.4, the
/// `// BEGIN GENERATED TOKEN PROPERTIES - Switch` block at :2168). Every
/// expected value below cites the line it was read from.
///
/// ## How a switch is measured
///
/// A `Switch` is not a tree of styled boxes: it is one `CustomPaint` whose
/// painter draws the track, the track outline, the state-layer circle and the
/// thumb (switch.dart:1508-1700). Geometry and colour are therefore read back
/// out of the paint stream with the harness probes ([paintedRRects],
/// [paintedFillColors], [paintedBorderSides]) rather than off widget
/// properties — which is also the only way to see what the *theme* contributed,
/// since none of it is visible on the `Switch` widget.
///
/// ## The one state this harness cannot drive
///
/// Pressed and focused are driven and measured below. Hovered is not: a
/// `Toggleable` takes its hovered state from `FocusableActionDetector`, and in
/// this harness a mouse that enters the switch never flips it — a stock
/// `Switch` pumped the same way keeps its resting `outline` thumb and paints no
/// state layer either, so this is a property of the test environment and not of
/// the component. The hovered overlay is therefore measured as the value the
/// theme *resolves* for that state, and the two states that can be driven are
/// asserted to paint exactly the value the same theme resolves for them, which
/// is what connects the resolved values to the pixels.
///
/// ## BaseDropdownButton
///
/// The other control in this file, `BaseDropdownButton`, is deliberately not
/// measured. It wraps `DropdownButton`, which is Material *2*'s dropdown: in
/// Flutter 3.44.4 `dropdown.dart` carries no `// BEGIN GENERATED TOKEN
/// PROPERTIES` block at all, so the SDK holds no M3 token set to measure it
/// against. Material 3's counterpart is `DropdownMenu`
/// (`dropdown_menu.dart`), and the app's own M3 selection field is
/// `BaseDropdown`, already measured against `DropdownButtonFormField` in
/// base_dropdown_conformance_test.dart. Inventing tokens for a component with
/// no specification would put values in the manifest that no oracle can
/// falsify, so this suite states the reason instead.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_animated_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

// ---------------------------------------------------------------------------
// The Material 3 oracle, pinned from the generated token block.
// ---------------------------------------------------------------------------

/// switch.dart:2377 (`_SwitchConfigM3.trackWidth`).
const double _m3TrackWidth = 52.0;

/// switch.dart:2375 (`_SwitchConfigM3.trackHeight`).
const double _m3TrackHeight = 32.0;

/// switch.dart:1744-1745 (`_SwitchPainter._paintTrackWith`): the track is drawn
/// as a rounded rectangle whose radius is half its height, i.e. a stadium.
const double _m3TrackCornerRadius = _m3TrackHeight / 2;

/// switch.dart:2392 (`_SwitchConfigM3.switchMinSize`,
/// `Size(kMinInteractiveDimension, kMinInteractiveDimension - 8.0)`) together
/// with :2360 (`switchHeight => switchMinSize.height + 8.0`): the control
/// occupies a full 48 dp square of pointer target.
const double _m3TapTargetSide = 48.0;

/// switch.dart:2354 (`_SwitchConfigM3.inactiveThumbRadius`, `16.0 / 2`).
const double _m3UnselectedThumbDiameter = 16.0;

/// switch.dart:2317 (`_SwitchConfigM3.activeThumbRadius`, `24.0 / 2`).
const double _m3SelectedThumbDiameter = 24.0;

/// switch.dart:2357 (`_SwitchConfigM3.pressedThumbRadius`, `28.0 / 2`) — the
/// thumb grows while the switch is held.
const double _m3PressedThumbDiameter = 28.0;

/// switch.dart:2298 (`_SwitchDefaultsM3.trackOutlineWidth`).
const double _m3TrackOutlineWidth = 2.0;

// ---------------------------------------------------------------------------
// Probes
// ---------------------------------------------------------------------------

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

Finder _switch() => find.byType(Switch);

/// The rounded rectangles a switch paints, in paint order: the track, the
/// track's outline, then the thumb (switch.dart:1738-1760).
List<RRect> _switchRRects(WidgetTester tester) =>
    paintedRRects(tester, _switch());

/// The thumb is the last rounded rectangle the painter draws.
double _thumbDiameter(WidgetTester tester) => _switchRRects(tester).last.width;

/// The track is the first one.
RRect _trackRRect(WidgetTester tester) => _switchRRects(tester).first;

/// The filled areas a switch paints. The first is the track, the last the
/// thumb; a state layer, when one is painted, sits between them as a circle.
List<Color> _switchFills(WidgetTester tester) =>
    paintedFillColors(tester, _switch());

Color _trackColor(WidgetTester tester) => _switchFills(tester).first;

Color _thumbColor(WidgetTester tester) => _switchFills(tester).last;

/// The stroked track outline, or [BorderSide.none] when nothing is stroked.
BorderSide _trackOutline(WidgetTester tester) {
  final List<BorderSide> sides = paintedBorderSides(tester, _switch());
  return sides.isEmpty ? BorderSide.none : sides.first;
}

String _role(WidgetTester tester, Color color) =>
    colorRoleName(_theme(tester).colorScheme, color);

/// Everything the switch paints that it did not paint at rest — the state
/// layer, and any colour the state changed.
List<Color> _fillsAddedBy(List<Color> resting, List<Color> now) {
  final List<Color> remaining = List<Color>.of(resting);
  final List<Color> added = <Color>[];
  for (final Color color in now) {
    if (!remaining.remove(color)) {
      added.add(color);
    }
  }
  return added;
}

/// Presses the switch with a mouse and holds it, pumping until the radial
/// reaction has finished growing.
///
/// The reaction is an `AnimationController` inside the painter rather than an
/// ink feature, so it needs a frame to start and a frame to finish; a single
/// long pump lands after the ticker was scheduled but before it ran.
Future<TestGesture> _pressAndHoldSwitch(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(_switch()),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

Widget _baseSwitch({
  bool value = false,
  bool enabled = true,
  Color? activeThumbColor,
  Color? activeTrackColor,
  Color? inactiveThumbColor,
  Color? inactiveTrackColor,
}) {
  return BaseSwitch(
    value: value,
    onChanged: enabled ? (bool _) {} : null,
    activeThumbColor: activeThumbColor,
    activeTrackColor: activeTrackColor,
    inactiveThumbColor: inactiveThumbColor,
    inactiveTrackColor: inactiveTrackColor,
  );
}

/// The overlay colour the app's `switchTheme` resolves for [states].
///
/// This is the value the painter is handed as its reaction colour
/// (switch.dart:1120-1141 resolves `overlayColor` into the painter's
/// `reactionColor`/`focusColor`/`hoverColor`), so reading it here and asserting
/// below that the driven states paint exactly it measures the same number twice
/// rather than two different ones.
Color? _resolvedOverlay(WidgetTester tester, Set<WidgetState> states) =>
    _theme(tester).switchTheme.overlayColor?.resolve(states);

void main() {
  group('track geometry', () {
    testWidgets('track width and height', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch());
      final RRect track = _trackRRect(tester);

      expectConformant(
        token: 'BaseSwitch.trackWidth',
        component: 'BaseSwitch',
        measured: track.width,
        expected: _m3TrackWidth,
      );
      expectConformant(
        token: 'BaseSwitch.trackHeight',
        component: 'BaseSwitch',
        measured: track.height,
        expected: _m3TrackHeight,
      );
    });

    testWidgets('the track is a stadium', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch());

      expectConformant(
        token: 'BaseSwitch.trackShape',
        component: 'BaseSwitch',
        measured: _trackRRect(tester).tlRadiusX,
        expected: _m3TrackCornerRadius,
      );
    });

    testWidgets('the control fills a 48 dp tap target', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseSwitch());
      final Size size = tester.getSize(_switch());

      // The width is 60 (the 52 dp track plus `_SwitchDefaultsM3.padding`,
      // switch.dart:2304), so the token measures the constrained dimension.
      expectConformant(
        token: 'BaseSwitch.tapTargetSize',
        component: 'BaseSwitch',
        measured: size.height,
        expected: _m3TapTargetSide,
      );
      expect(size.width, greaterThanOrEqualTo(_m3TapTargetSide));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('thumb geometry', () {
    testWidgets('an unselected thumb is 16 dp', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch());

      expectConformant(
        token: 'BaseSwitch.unselected.thumbDiameter',
        component: 'BaseSwitch',
        measured: _thumbDiameter(tester),
        expected: _m3UnselectedThumbDiameter,
      );
    });

    testWidgets('a selected thumb is 24 dp', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch(value: true));
      await tester.pumpAndSettle();

      expectConformant(
        token: 'BaseSwitch.selected.thumbDiameter',
        component: 'BaseSwitch',
        measured: _thumbDiameter(tester),
        expected: _m3SelectedThumbDiameter,
      );
    });

    testWidgets('the thumb grows to 28 dp while pressed', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseSwitch());
      expect(
        _thumbDiameter(tester),
        _m3UnselectedThumbDiameter,
        reason:
            'the resting thumb must be the small one, or the growth '
            'measured below would be measuring nothing',
      );

      final TestGesture gesture = await _pressAndHoldSwitch(tester);
      final double pressed = _thumbDiameter(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expectConformant(
        token: 'BaseSwitch.pressed.thumbDiameter',
        component: 'BaseSwitch',
        measured: pressed,
        expected: _m3PressedThumbDiameter,
      );
    });
  });

  group('resting colour roles', () {
    testWidgets('an unselected switch', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch());
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSwitch.unselected.trackColor',
        component: 'BaseSwitch',
        measured: _role(tester, _trackColor(tester)),
        // switch.dart:2246 (`_SwitchDefaultsM3.trackColor`, resting).
        expected: colorRoleName(scheme, scheme.surfaceContainerHighest),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.unselected.thumbColor',
        component: 'BaseSwitch',
        measured: _role(tester, _thumbColor(tester)),
        // switch.dart:2212 (`_SwitchDefaultsM3.thumbColor`, resting).
        expected: colorRoleName(scheme, scheme.outline),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.unselected.trackOutline',
        component: 'BaseSwitch',
        measured: describeBorderSide(scheme, _trackOutline(tester)),
        // switch.dart:2259 and :2298.
        expected: describeBorderSide(
          scheme,
          BorderSide(color: scheme.outline, width: _m3TrackOutlineWidth),
        ),
        unit: '',
      );
    });

    testWidgets('a selected switch', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch(value: true));
      await tester.pumpAndSettle();
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSwitch.selected.trackColor',
        component: 'BaseSwitch',
        measured: _role(tester, _trackColor(tester)),
        // switch.dart:2235 (`_SwitchDefaultsM3.trackColor`, selected).
        expected: colorRoleName(scheme, scheme.primary),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.selected.thumbColor',
        component: 'BaseSwitch',
        measured: _role(tester, _thumbColor(tester)),
        // switch.dart:2201 (`_SwitchDefaultsM3.thumbColor`, selected).
        expected: colorRoleName(scheme, scheme.onPrimary),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.selected.trackOutline',
        component: 'BaseSwitch',
        measured: describeBorderSide(scheme, _trackOutline(tester)),
        // switch.dart:2254 (`trackOutlineColor`, transparent while selected).
        expected: describeBorderSide(
          scheme,
          const BorderSide(color: Color(0x00000000), width: 2),
        ),
        unit: '',
      );
    });
  });

  group('disabled treatment', () {
    testWidgets('a disabled unselected switch', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch(enabled: false));
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSwitch.disabled.unselected.trackColor',
        component: 'BaseSwitch',
        measured: _role(tester, _trackColor(tester)),
        // switch.dart:2223.
        expected: colorRoleName(
          scheme,
          scheme.surfaceContainerHighest.withValues(alpha: 0.12),
        ),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.disabled.unselected.thumbColor',
        component: 'BaseSwitch',
        measured: _role(tester, _thumbColor(tester)),
        // switch.dart:2189 gives the thumb `onSurface` at 38%, and :1667
        // composites it over the surface so the track cannot show through it,
        // so the painted colour is the blend rather than the translucent role.
        expected: colorRoleName(
          scheme,
          Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.38),
            scheme.surface,
          ),
        ),
        unit: '',
      );
    });

    testWidgets('a disabled selected switch', (WidgetTester tester) async {
      await pumpConformance(tester, _baseSwitch(value: true, enabled: false));
      await tester.pumpAndSettle();
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSwitch.disabled.selected.trackColor',
        component: 'BaseSwitch',
        measured: _role(tester, _trackColor(tester)),
        // switch.dart:2221.
        expected: colorRoleName(
          scheme,
          scheme.onSurface.withValues(alpha: 0.12),
        ),
        unit: '',
      );
      expectConformant(
        token: 'BaseSwitch.disabled.selected.thumbColor',
        component: 'BaseSwitch',
        measured: _role(tester, _thumbColor(tester)),
        // switch.dart:2187 (`surface` at full opacity).
        expected: colorRoleName(scheme, scheme.surface),
        unit: '',
      );
    });
  });

  group('state layers', () {
    testWidgets('hovered overlay (resolved, see the library comment)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseSwitch());
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color? overlay = _resolvedOverlay(tester, <WidgetState>{
        WidgetState.hovered,
      });
      expect(overlay, isNotNull, reason: 'a switch must have a hover layer');

      expectConformant(
        token: 'BaseSwitch.overlay.hovered',
        component: 'BaseSwitch',
        measured: _role(tester, overlay!),
        // switch.dart:2282 (`overlayColor`, hovered and unselected).
        expected: colorRoleName(
          scheme,
          scheme.onSurface.withValues(alpha: 0.08),
        ),
        unit: '',
      );
    });

    testWidgets('focus paints the resolved overlay', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseSwitch());
      final ColorScheme scheme = _theme(tester).colorScheme;
      final List<Color> resting = _switchFills(tester);
      await focusFirstWithTab(tester);
      final List<Color> added = _fillsAddedBy(resting, _switchFills(tester));

      final Color? resolved = _resolvedOverlay(tester, <WidgetState>{
        WidgetState.focused,
      });
      expect(
        added.map((Color color) => color.toARGB32()),
        contains(resolved!.toARGB32()),
        reason:
            'the focused switch must paint the overlay its theme resolves; '
            'measuring the resolved value alone would not prove it reaches '
            'the pixels',
      );

      expectConformant(
        token: 'BaseSwitch.overlay.focused',
        component: 'BaseSwitch',
        measured: _role(tester, resolved),
        // switch.dart:2285 (`overlayColor`, focused and unselected).
        expected: colorRoleName(
          scheme,
          scheme.onSurface.withValues(alpha: 0.1),
        ),
        unit: '',
      );
    });

    testWidgets('press paints the resolved overlay', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseSwitch());
      final ColorScheme scheme = _theme(tester).colorScheme;
      final List<Color> resting = _switchFills(tester);
      final TestGesture gesture = await _pressAndHoldSwitch(tester);
      final List<Color> added = _fillsAddedBy(resting, _switchFills(tester));
      await gesture.up();
      await tester.pumpAndSettle();

      final Color? resolved = _resolvedOverlay(tester, <WidgetState>{
        WidgetState.pressed,
      });
      expect(
        added.map((Color color) => color.toARGB32()),
        contains(resolved!.toARGB32()),
        reason: 'the pressed switch must paint the overlay its theme resolves',
      );

      expectConformant(
        token: 'BaseSwitch.overlay.pressed',
        component: 'BaseSwitch',
        measured: _role(tester, resolved),
        // switch.dart:2279 (`overlayColor`, pressed and unselected).
        expected: colorRoleName(
          scheme,
          scheme.onSurface.withValues(alpha: 0.1),
        ),
        unit: '',
      );
    });

    testWidgets('a selected switch focuses in its own role', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseSwitch(value: true));
      await tester.pumpAndSettle();
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color? resolved = _resolvedOverlay(tester, <WidgetState>{
        WidgetState.selected,
        WidgetState.focused,
      });

      expectConformant(
        token: 'BaseSwitch.selected.overlay.focused',
        component: 'BaseSwitch',
        measured: _role(tester, resolved!),
        // switch.dart:2274 (`overlayColor`, focused and selected).
        expected: colorRoleName(scheme, scheme.primary.withValues(alpha: 0.1)),
        unit: '',
      );
    });
  });

  // -------------------------------------------------------------------------
  // The caller-colour contract.
  //
  // BaseSwitch accepts four colours and used to mishandle them in two ways:
  // the inactive pair was accepted and dropped on the floor, and the active
  // pair went through `WidgetStateProperty.all`, so it painted in every state
  // including the unselected and the disabled one. The repair is asserted here
  // on what the component *paints*, not on the property it hands to `Switch`:
  // a property that resolves correctly and never reaches the canvas would pass
  // the widget-level test in
  // test/shared/components/base_animated_widgets_test.dart and still be wrong.
  // -------------------------------------------------------------------------
  group('caller colours per state', () {
    const Color callerActiveThumb = Color(0xFF00FF00);
    const Color callerActiveTrack = Color(0xFF008800);
    const Color callerInactiveThumb = Color(0xFFFF0000);
    const Color callerInactiveTrack = Color(0xFF880000);

    // A switch that changes `value` in place animates between the two
    // treatments over 300 ms and lerps every colour on the way
    // (switch.dart:1660-1667), so each arrangement is settled before it is
    // read; measuring on the frame after the pump would report a colour that
    // is halfway between the two states and belongs to neither.
    Future<void> pumpSettled(WidgetTester tester, Widget child) async {
      await pumpConformance(tester, child);
      await tester.pumpAndSettle();
    }

    testWidgets('the active pair paints only while selected', (
      WidgetTester tester,
    ) async {
      await pumpSettled(
        tester,
        _baseSwitch(
          value: true,
          activeThumbColor: callerActiveThumb,
          activeTrackColor: callerActiveTrack,
        ),
      );
      expect(_trackColor(tester).toARGB32(), callerActiveTrack.toARGB32());
      expect(_thumbColor(tester).toARGB32(), callerActiveThumb.toARGB32());

      // The regression: with only the active pair given, the unselected switch
      // must be exactly what it is with no colours at all.
      await pumpSettled(tester, _baseSwitch());
      final String untinted =
          '${_role(tester, _trackColor(tester))} / '
          '${_role(tester, _thumbColor(tester))}';

      await pumpSettled(
        tester,
        _baseSwitch(
          activeThumbColor: callerActiveThumb,
          activeTrackColor: callerActiveTrack,
        ),
      );
      expect(
        '${_role(tester, _trackColor(tester))} / '
        '${_role(tester, _thumbColor(tester))}',
        untinted,
        reason:
            'an unselected switch given only active colours must keep the '
            "theme's unselected treatment",
      );
    });

    testWidgets('the inactive pair paints only while unselected', (
      WidgetTester tester,
    ) async {
      await pumpSettled(
        tester,
        _baseSwitch(
          inactiveThumbColor: callerInactiveThumb,
          inactiveTrackColor: callerInactiveTrack,
        ),
      );
      expect(_trackColor(tester).toARGB32(), callerInactiveTrack.toARGB32());
      expect(_thumbColor(tester).toARGB32(), callerInactiveThumb.toARGB32());

      await pumpSettled(
        tester,
        _baseSwitch(
          value: true,
          inactiveThumbColor: callerInactiveThumb,
          inactiveTrackColor: callerInactiveTrack,
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(
        _trackColor(tester).toARGB32(),
        scheme.primary.toARGB32(),
        reason:
            'a selected switch given only inactive colours must keep the M3 '
            'selected track',
      );
    });

    testWidgets('a disabled switch ignores all four and keeps the M3 '
        'disabled treatment', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        _baseSwitch(
          enabled: false,
          activeThumbColor: callerActiveThumb,
          activeTrackColor: callerActiveTrack,
          inactiveThumbColor: callerInactiveThumb,
          inactiveTrackColor: callerInactiveTrack,
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;

      expect(
        _trackColor(tester).toARGB32(),
        scheme.surfaceContainerHighest.withValues(alpha: 0.12).toARGB32(),
        reason:
            'a disabled switch must paint the M3 disabled track '
            '(switch.dart:2223), never a caller colour: the caller cannot know '
            'which of its colours still reads as unavailable',
      );
    });
  });
}
