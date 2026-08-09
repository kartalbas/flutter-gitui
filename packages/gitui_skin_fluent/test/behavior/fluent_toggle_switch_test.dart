/// The switch's feel, measured from the paint stream.
///
/// What a WinUI switch does that a reimplementation gets wrong: the OFF
/// track is a recessed well behind a STRONG FILL border (not the button's
/// hairline); the ON track is the accent that dims by opacity; and the
/// knob is not a dot that teleports - it STRETCHES toward the pointer,
/// wider under hover and wider again under press, before it slides.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_toggle_switch.dart';

import 'support/fluent_behavior_harness.dart';

// ---------------------------------------------------------------------------
// Pinned WinUI resources (fluent_ui@4.16.1 lib/src/styles/color_resources.dart
// unless noted).
// ---------------------------------------------------------------------------

// ControlAltFillColorSecondary / Tertiary, light theme: :302, :303.
const Color _wellRestLight = Color(0x06000000);
const Color _wellHoverLight = Color(0x0f000000);

// ControlStrongFillColorDefault, light theme: :294 - the OFF border.
const Color _strongFillLight = Color(0x72000000);

// The accent's dark stop: the resting ON fill in a light theme
// (color.dart:171, brush rule :347-352).
const Color _accentRestLight = Color(0xff0066b4);

// TextFillColorSecondary, light: :278 - the OFF knob's ink.
const Color _offKnobLight = Color(0x9e000000);

// TextOnAccentFillColorPrimary, light: :284 - the ON knob's ink.
const Color _onKnobLight = Color(0xFFffffff);

Finder _track() => find.byType(FluentToggleSwitchTrack);

/// The knob's painted rounded rectangle: the SMALLEST rrect painted under
/// the track (the track itself is the 40-wide stadium).
RRect _knobRect(WidgetTester tester) {
  final List<RRect> rects = paintedRRects(tester, _track());
  expect(rects, isNotEmpty);
  rects.sort((RRect a, RRect b) => a.width.compareTo(b.width));
  return rects.first;
}

void main() {
  group('off, light', () {
    testWidgets('rests on the well behind the strong-fill border, knob in '
        'the secondary ink', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: false, onChanged: (bool? _) {}),
        ),
      );
      final List<Color> fills = paintedFillColors(tester, _track());
      expect(
        fills,
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _wellRestLight.toARGB32(),
          ),
        ),
        reason: 'the off track is ControlAltFillColorSecondary (:302)',
      );
      expect(
        fills,
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _offKnobLight.toARGB32(),
          ),
        ),
        reason:
            'the off knob is TextFillColorSecondary '
            '(toggle_switch.dart:480-486)',
      );
      expect(
        paintedStrokes(tester, _track()).single.color.toARGB32(),
        _strongFillLight.toARGB32(),
        reason:
            'the off border is ControlStrongFillColorDefault '
            '(toggle_switch.dart:459-465) - a FILL resource, not the '
            'button hairline',
      );
    });

    testWidgets('hover deepens the well and stretches the knob', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: false, onChanged: (bool? _) {}),
        ),
      );
      final double restingWidth = _knobRect(tester).width;
      await hoverOver(tester, _track());
      expect(
        paintedFillColors(tester, _track()),
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _wellHoverLight.toARGB32(),
          ),
        ),
      );
      expect(
        _knobRect(tester).width,
        greaterThan(restingWidth),
        reason:
            'hover grows the knob (toggle_switch.dart:305-316: +2 epx and '
            'a relaxed margin) - the stretch toward the pointer',
      );
    });

    testWidgets('press stretches the knob further than hover', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: false, onChanged: (bool? _) {}),
        ),
      );
      await hoverOver(tester, _track());
      final double hoveredWidth = _knobRect(tester).width;
      final TestGesture gesture = await pressAndHold(tester, _track());
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _knobRect(tester).width,
        greaterThan(hoveredWidth),
        reason: 'press adds 5 epx more (toggle_switch.dart:314-316)',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('on, light', () {
    testWidgets('rests on the accent, knob in the on-accent ink', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: true, onChanged: (bool? _) {}),
        ),
      );
      final List<Color> fills = paintedFillColors(tester, _track());
      expect(
        fills,
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _accentRestLight.toARGB32(),
          ),
        ),
      );
      expect(
        fills,
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _onKnobLight.toARGB32(),
          ),
        ),
      );
    });

    testWidgets('the knob sits at opposite ends for on and off', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: false, onChanged: (bool? _) {}),
        ),
      );
      final double offCenter = _knobRect(tester).center.dx;
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(value: true, onChanged: (bool? _) {}),
        ),
      );
      await tester.pumpAndSettle();
      final double onCenter = _knobRect(tester).center.dx;
      expect(
        onCenter,
        greaterThan(offCenter),
        reason:
            'on aligns the knob to the end, off to the start '
            '(toggle_switch.dart:229-236)',
      );
    });
  });

  group('operating it', () {
    testWidgets('tap reports the flipped value, mixed resolves to on', (
      WidgetTester tester,
    ) async {
      bool? reported;
      await pumpFluentBehavior(
        tester,
        FluentToggleSwitch(
          spec: ToggleSpec(
            value: null,
            onChanged: (bool? next) => reported = next,
          ),
        ),
      );
      await tester.tap(_track());
      expect(
        reported,
        isTrue,
        reason: 'a mixed switch reads as "not on", so operating it turns on',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('disabled means no states at all', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        const FluentToggleSwitch(
          spec: ToggleSpec(value: false, onChanged: null),
        ),
      );
      final double restingWidth = _knobRect(tester).width;
      await hoverOver(tester, _track());
      expect(
        _knobRect(tester).width,
        restingWidth,
        reason: 'a disabled switch does not stretch its knob',
      );
    });
  });
}
