/// The `surfaces.pressable` member: WHERE THE FEEL LIVES.
///
/// A pressable region is the one surface whose whole job is answering the
/// pointer and the keyboard, so it gets the full behaviour treatment: every
/// state read from the PAINT STREAM under real input, never from widget
/// properties, and every assertion is one a reimplementation gets wrong -
/// the ladder's direction, the pressed fill RECEDING below the hover fill,
/// the two-stroke focus rectangle that only the keyboard may reveal, and
/// the 83 ms container animation.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_surfaces.dart';
import 'package:gitui_skin_fluent/src/fluent_motion.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';

import 'support/fluent_behavior_harness.dart';

const FluentResources _light = FluentResources.light();
const FluentResources _dark = FluentResources.dark();

/// The pressable member, built exactly as the application reaches it.
Widget _pressable(PressableSpec spec) => Builder(
  builder: (BuildContext context) =>
      const FluentSurfaces().pressable(context, spec),
);

/// The region's visual container.
Finder _box() => find.byType(AnimatedContainer);

void main() {
  group('the subtle ladder', () {
    testWidgets('at rest the region paints NO fill - subtle means invisible '
        'until touched', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      final Color fill = singleFillOf(tester, _box());
      expect(
        fill.a,
        0,
        reason:
            'SubtleFillColorTransparent (buttons/theme.dart:377-379): a '
            'subtle control rests with no fill at all',
      );
    });

    testWidgets('hover paints the subtle hover fill, and it DARKENS the '
        'light ground - the direction a Material reimplementation gets '
        'wrong', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      await hoverOver(tester, _box());
      final Color fill = singleFillOf(tester, _box());
      expectPaintedColor(fill, _light.subtleFillColorSecondary);
      final Color ground = _light.solidBackgroundFillColorBase;
      expect(
        luminanceOver(ground, fill),
        lessThan(ground.computeLuminance()),
        reason: 'the hover layer is translucent black over the light ground',
      );
    });

    testWidgets('the pressed fill RECEDES: darker than rest, FAINTER than '
        'hover - the signature a reimplementation that presses harder than '
        'it hovers destroys', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      final Color ground = _light.solidBackgroundFillColorBase;
      final double atRest = ground.computeLuminance();

      final TestGesture hover = await hoverOver(tester, _box());
      final double hovered = luminanceOver(
        ground,
        singleFillOf(tester, _box()),
      );
      await hoverAway(tester, hover);

      final TestGesture press = await pressAndHold(tester, _box());
      final double pressed = luminanceOver(
        ground,
        singleFillOf(tester, _box()),
      );
      await press.up();
      await tester.pumpAndSettle();

      expect(
        pressed,
        lessThan(atRest),
        reason: 'pressing darkens the region (theme.dart:375)',
      );
      expect(
        pressed,
        greaterThan(hovered),
        reason:
            'the pressed fill (SubtleFillColorTertiary, 2.3%) sits BETWEEN '
            'rest and hover (Secondary, 3.5%): a Fluent press recedes under '
            'the finger where a Material state layer presses deeper',
      );
    });

    testWidgets('the same ordering holds in the dark theme, where hover '
        'LIGHTENS', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
        brightness: Brightness.dark,
      );
      final Color ground = _dark.solidBackgroundFillColorBase;
      final double atRest = ground.computeLuminance();

      final TestGesture hover = await hoverOver(tester, _box());
      final double hovered = luminanceOver(
        ground,
        singleFillOf(tester, _box()),
      );
      await hoverAway(tester, hover);

      final TestGesture press = await pressAndHold(tester, _box());
      final double pressed = luminanceOver(
        ground,
        singleFillOf(tester, _box()),
      );
      await press.up();
      await tester.pumpAndSettle();

      expect(hovered, greaterThan(atRest), reason: 'dark hover lightens');
      expect(pressed, greaterThan(atRest), reason: 'dark press lightens too');
      expect(
        pressed,
        lessThan(hovered),
        reason: 'and still recedes below the hover fill',
      );
    });

    testWidgets('a selected region wears the hover fill at rest - WinUI\'s '
        'own selected-tile treatment', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () {},
            selected: true,
          ),
        ),
      );
      expectPaintedColor(
        singleFillOf(tester, _box()),
        _light.subtleFillColorSecondary,
        reason:
            'a selected tile resolves with the hovered state unioned in '
            '(list_tile.dart:280-286)',
      );
    });
  });

  group('the press', () {
    testWidgets('begins on pointer DOWN, not on the click', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      final TestGesture gesture = await pressAndHold(tester, _box());
      // The finger is still down and the pressed fill is already painted.
      expectPaintedColor(
        singleFillOf(tester, _box()),
        _light.subtleFillColorTertiary,
        reason: 'the region answers the finger, not the click',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the fill ANIMATES to its new state - a region that '
        'snaps is not Fluent', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      // Drive the hover by hand so the mid-flight frame can be read: the
      // shared driver settles, and a settled animation hides its own
      // existence.
      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(() => gesture.removePointer());
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_box()));
      await tester.pump();
      // Mid-flight: 40 ms into the 83 ms container step.
      await tester.pump(const Duration(milliseconds: 40));
      final Color midway = singleFillOf(tester, _box());
      expect(
        midway.a,
        greaterThan(0),
        reason: 'the fill has started moving by 40 ms',
      );
      expect(
        midway.a * 255,
        lessThan(_light.subtleFillColorSecondary.a * 255 - 0.5),
        reason:
            'and has not arrived: the container answers at the 83 ms '
            'faster step (theme.dart:440), so 40 ms is mid-animation',
      );
      // Settled by the end of the step.
      await tester.pump(const Duration(milliseconds: 60));
      expectPaintedColor(
        singleFillOf(tester, _box()),
        _light.subtleFillColorSecondary,
      );
    });
  });

  group('the focus rectangle', () {
    testWidgets('is TWO strokes - dark outer, light inner - so it stays '
        'legible on any fill', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      await focusWithTab(tester);
      final List<PaintedStroke> strokes = paintedStrokes(
        tester,
        focusRingBox(),
      );
      expect(strokes, hasLength(2));
      expectPaintedColor(strokes.first.color, _light.focusStrokeColorOuter);
      expect(strokes.first.width, 2);
      expect(strokes.first.outerRadius, 6);
      expectPaintedColor(strokes.last.color, _light.focusStrokeColorInner);
      expect(strokes.last.width, 1);
    });

    testWidgets('the pointer NEVER reveals it - keyboard-only is WinUI\'s '
        'own rule', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
      );
      await hoverOver(tester, _box());
      expect(paintedStrokes(tester, focusRingBox()), isEmpty);
      final TestGesture gesture = await pressAndHold(tester, _box());
      expect(paintedStrokes(tester, focusRingBox()), isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the rectangle inverts with the theme so it holds on the '
        'dark ground', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(child: const ContentPort(Text('region')), onTap: () {}),
        ),
        brightness: Brightness.dark,
      );
      await focusWithTab(tester);
      final List<PaintedStroke> strokes = paintedStrokes(
        tester,
        focusRingBox(),
      );
      expect(strokes, hasLength(2));
      expectPaintedColor(strokes.first.color, _dark.focusStrokeColorOuter);
      expectPaintedColor(strokes.last.color, _dark.focusStrokeColorInner);
    });
  });

  group('the keyboard', () {
    testWidgets('Enter activates the focused region', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () => taps++,
          ),
        ),
      );
      await focusWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('disabled', () {
    testWidgets('a disabled region wears no state at all: hover changes '
        'nothing', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () {},
            enabled: false,
          ),
        ),
      );
      await hoverOver(tester, _box());
      expect(
        singleFillOf(tester, _box()).a,
        0,
        reason:
            'the state set collapses to {disabled} '
            '(hover_button.dart:295-303): a hover over a disabled region '
            'paints nothing',
      );
    });

    testWidgets('a disabled region cannot be tapped', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );
      await tester.tap(_box(), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('gestures beyond the tap', () {
    testWidgets('the double click is recognised from the interval, so the '
        'FIRST tap still answers immediately', (WidgetTester tester) async {
      int taps = 0;
      int opens = 0;
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () => taps++,
            onDoubleTap: () => opens++,
          ),
        ),
      );
      await tester.tap(_box());
      await tester.pump();
      expect(
        taps,
        1,
        reason: 'the single tap is not held for the 300 ms double-tap window',
      );
      await tester.tap(_box());
      await tester.pump();
      expect(taps, 2);
      expect(opens, 1, reason: 'the second tap within the window opens');
      // Drain the 100 ms pressed-release hold both taps armed.
      await tester.pump(FluentMotion.pressedRelease * 2);
    });

    testWidgets('the secondary button reports the context menu with its '
        'position', (WidgetTester tester) async {
      Offset? at;
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onContextMenu: (Offset offset) => at = offset,
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_box()),
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pump();
      expect(at, isNotNull);
      expect(at, tester.getCenter(_box()));
    });
  });

  group('semantics', () {
    testWidgets('the region carries its name, its selection and its '
        'announced tooltip', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _pressable(
          PressableSpec(
            child: const ContentPort(Text('region')),
            onTap: () {},
            selected: true,
            tooltip: 'Does the thing',
            semanticsLabel: 'The region',
          ),
        ),
      );
      final SemanticsHandle semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('The region')),
        matchesSemantics(
          label: 'The region',
          tooltip: 'Does the thing',
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    });
  });
}
