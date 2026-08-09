/// The icon button's feel, measured from the paint stream.
///
/// The WinUI icon button is a SUBTLE control: invisible at rest, a wash
/// under the pointer, a fainter wash under the press - the inversion a
/// Material reimplementation gets wrong, because Material's press is
/// LOUDER than its hover while Fluent's subtle press is QUIETER (the
/// control yields). Selection is not a tint: a selected icon button flips
/// to the checked accent fill wholesale.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_icon_button.dart';

import 'support/fluent_behavior_harness.dart';

// ---------------------------------------------------------------------------
// Pinned WinUI resources (fluent_ui@4.16.1 lib/src/styles/color_resources.dart
// unless noted).
// ---------------------------------------------------------------------------

// SubtleFillColorTransparent / Secondary / Tertiary, light theme:
// :297, :298, :299.
const Color _subtleRestLight = Color(0x00ffffff);
const Color _subtleHoverLight = Color(0x09000000);
const Color _subtlePressedLight = Color(0x06000000);

// The accent's dark stop (color.dart:171): the selected fill, light theme.
const Color _accentRestLight = Color(0xff0066b4);

// FocusStrokeColorOuter / Inner, light theme: :326, :327.
const Color _focusOuterLight = Color(0xe4000000);
const Color _focusInnerLight = Color(0xb3ffffff);

IconButtonSpec _spec({
  VoidCallback? onPressed,
  bool? selected,
  int? badgeCount,
}) => IconButtonSpec(
  icon: IconRole.gear,
  tooltip: 'Settings',
  onPressed: onPressed,
  selected: selected,
  badgeCount: badgeCount,
);

Finder _box() => find.descendant(
  of: find.byType(FluentIconButton),
  matching: find.byType(AnimatedContainer),
);

void main() {
  group('subtle ladder, light', () {
    testWidgets('rests invisible, hover washes, press washes FAINTER than '
        'hover', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {})),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _subtleRestLight.toARGB32(),
        reason:
            'at rest a subtle control paints nothing '
            '(icon_button.dart:116-125)',
      );
      await hoverOver(tester, _box());
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _subtleHoverLight.toARGB32(),
      );
      final TestGesture gesture = await pressAndHold(tester, _box());
      final Color pressed = singleFillOf(tester, _box());
      expect(pressed.toARGB32(), _subtlePressedLight.toARGB32());
      expect(
        pressed.a,
        lessThan(_subtleHoverLight.a),
        reason:
            'the subtle press is FAINTER than its hover (0x06 under 0x09, '
            'color_resources.dart:298-299) - the control yields where '
            'Material\'s press gets louder',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('disabled means no states at all', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, FluentIconButton(spec: _spec()));
      final Color resting = singleFillOf(tester, _box());
      await hoverOver(tester, _box());
      expect(singleFillOf(tester, _box()).toARGB32(), resting.toARGB32());
    });
  });

  group('selection', () {
    testWidgets('selected flips to the checked accent fill', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {}, selected: true)),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _accentRestLight.toARGB32(),
        reason:
            'a selected icon button is the ToggleButton checked '
            'treatment (toggle_button.dart:162-169)',
      );
    });

    testWidgets('selected false stays on the subtle ladder', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {}, selected: false)),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _subtleRestLight.toARGB32(),
      );
    });
  });

  group('focus and keyboard', () {
    testWidgets('Tab reveals the two-stroke rectangle; Enter activates', (
      WidgetTester tester,
    ) async {
      int presses = 0;
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () => presses++)),
      );
      expect(
        paintedStrokes(tester, focusRingBox()),
        isEmpty,
        reason: 'no focus rectangle before the keyboard is used',
      );
      await focusWithTab(tester);
      final List<PaintedStroke> strokes = paintedStrokes(
        tester,
        focusRingBox(),
      );
      expect(strokes, hasLength(2));
      expect(strokes.first.color.toARGB32(), _focusOuterLight.toARGB32());
      expect(strokes.last.color.toARGB32(), _focusInnerLight.toARGB32());
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(presses, 1);
    });

    testWidgets('a pointer never reveals the rectangle', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {})),
      );
      await hoverOver(tester, _box());
      final TestGesture gesture = await pressAndHold(tester, _box());
      expect(paintedStrokes(tester, focusRingBox()), isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the badge and the name', () {
    testWidgets('a count renders as the InfoBadge numerals', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {}, badgeCount: 5)),
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('the tooltip is the accessible name', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentIconButton(spec: _spec(onPressed: () {})),
      );
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    });
  });
}
