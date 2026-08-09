/// FOCUS, measured from the paint stream.
///
/// Behaviour 2 of the Fluent behaviour suite. Fluent's high-visibility
/// focus rectangle is TWO strokes - a 2 epx outer and a 1 epx inner, always
/// on opposite sides of the light/dark ledger - precisely so it stays
/// legible on both grounds and over any fill. And it is KEYBOARD-ONLY: a
/// pointer never reveals it (WinUI "Focus visuals": focus visuals are only
/// rendered on keyboard input). Both facts, plus the keyboard activation
/// behaviours that come with focus, are asserted here.
///
/// Sources cited throughout: fluent_ui@4.16.1
/// lib/src/controls/utils/focus.dart (metrics and structure),
/// lib/src/controls/utils/hover_button.dart (activation), and the WinUI
/// focus-visuals design page for the keyboard-only rule.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';

import 'support/fluent_behavior_harness.dart';

// FocusStrokeColorOuter / Inner, light theme: fluent_ui@4.16.1
// color_resources.dart:326-327.
const Color _outerLight = Color(0xe4000000);
const Color _innerLight = Color(0xb3ffffff);

// The same pair, dark theme: color_resources.dart:239-240.
const Color _outerDark = Color(0xFFffffff);
const Color _innerDark = Color(0xb3000000);

// ControlFillColorDefault, light: color_resources.dart:287 - what the fill
// must STILL be while focused.
const Color _standardRestLight = Color(0xb3ffffff);

Widget _button({VoidCallback? onPressed}) => FluentButton(
  spec: ButtonSpec(
    label: 'Probe',
    emphasis: Emphasis.secondary,
    onPressed: onPressed,
  ),
);

void main() {
  testWidgets('unfocused, the rectangle paints nothing at all', (
    WidgetTester tester,
  ) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    expect(paintedStrokes(tester, focusRingBox()), isEmpty);
  });

  testWidgets('keyboard focus paints TWO strokes: 2 epx outer, then 1 epx '
      'inner, and they differ', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    await focusWithTab(tester);
    expect(
      tester.binding.focusManager.primaryFocus,
      isNotNull,
      reason: 'Tab must move focus onto the button',
    );
    final List<PaintedStroke> strokes = paintedStrokes(tester, focusRingBox());
    expect(
      strokes,
      hasLength(2),
      reason:
          'the high-visibility rectangle is exactly two strokes '
          '(fluent_ui focus.dart:210-222); one stroke is the '
          'reimplementation shortcut that stops being legible over an '
          'accent fill',
    );
    // Paint order: the outer decoration paints before the nested inner one.
    expect(strokes[0].width, 2.0, reason: 'outer stroke: 2 epx');
    expect(strokes[0].color.toARGB32(), _outerLight.toARGB32());
    expect(strokes[1].width, 1.0, reason: 'inner stroke: 1 epx');
    expect(strokes[1].color.toARGB32(), _innerLight.toARGB32());
    expect(
      strokes[0].color.toARGB32(),
      isNot(strokes[1].color.toARGB32()),
      reason: 'the two strokes must differ - that difference IS the design',
    );
  });

  testWidgets('the two strokes sit on opposite sides of the ledger, in '
      'both themes', (WidgetTester tester) async {
    // Light: dark outer, light inner. Dark: light outer, dark inner. This
    // inversion is what keeps the pair legible over any ground
    // (color_resources.dart:326-327 vs :239-240).
    expect(
      _outerLight.computeLuminance(),
      lessThan(_innerLight.computeLuminance()),
    );
    expect(
      _outerDark.computeLuminance(),
      greaterThan(_innerDark.computeLuminance()),
    );
    // And the dark pair is what is actually painted under the dark theme:
    await pumpFluentBehavior(
      tester,
      _button(onPressed: () {}),
      brightness: Brightness.dark,
    );
    await focusWithTab(tester);
    final List<PaintedStroke> strokes = paintedStrokes(tester, focusRingBox());
    expect(strokes, hasLength(2));
    expect(strokes[0].color.toARGB32(), _outerDark.toARGB32());
    expect(strokes[1].color.toARGB32(), _innerDark.toARGB32());
  });

  testWidgets('the rectangle stands OUTSIDE the control, by the sum of '
      'both stroke widths', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    await focusWithTab(tester);
    final Size control = tester.getSize(buttonContainer());
    final Size ring = tester.getSize(focusRingBox());
    // 3 epx on every side: outer 2 + inner 1 (fluent_ui focus.dart:93-108,
    // renderOutside defaulting true at :220). A rectangle drawn INSIDE
    // would eat the control's own border.
    expect(ring.width, control.width + 6);
    expect(ring.height, control.height + 6);
  });

  testWidgets('the outer stroke rounds at 6 epx - the control corner grown '
      'by the stand-off', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    await focusWithTab(tester);
    final List<PaintedStroke> strokes = paintedStrokes(tester, focusRingBox());
    expect(strokes, isNotEmpty);
    // The 4 epx control corner grown by the 2 epx stand-off (fluent_ui
    // focus.dart:212: BorderRadius.circular(6)).
    expect(strokes.first.outerRadius, 6.0);
  });

  testWidgets('focus changes the fill NOT AT ALL - the rectangle is the '
      'whole treatment', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    await focusWithTab(tester);
    expect(
      containerFill(tester).toARGB32(),
      _standardRestLight.toARGB32(),
      reason:
          'Fluent\'s state tables carry no focused branch (fluent_ui '
          'buttons/theme.dart:292-323) - unlike Material, which paints a '
          'focus state layer into the container. A focused Fluent button '
          'still RESTS; only the rectangle marks it.',
    );
  });

  testWidgets('a pointer press reveals no rectangle - focus visuals are '
      'keyboard-only', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    final TestGesture gesture = await pressAndHold(
      tester,
      find.byType(FluentButton),
    );
    expect(
      paintedStrokes(tester, focusRingBox()),
      isEmpty,
      reason:
          'WinUI: "focus visuals are only rendered when keyboard input is '
          'used"; the pressable routes focus display through the '
          'framework\'s interaction mode (FocusableActionDetector.'
          'onShowFocusHighlight, the reference\'s own wiring at '
          'hover_button.dart:357-359) so pointer interaction never shows '
          'the rectangle',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Enter and Space each activate the focused button', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await pumpFluentBehavior(tester, _button(onPressed: () => pressed++));
    await focusWithTab(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(pressed, 1, reason: 'Enter must activate the focused button');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(pressed, 2, reason: 'Space must activate the focused button');
  });

  testWidgets('a keyboard activation FLASHES the pressed state, then lets '
      'go on its own', (WidgetTester tester) async {
    // A pointer press is held as long as the finger; a keyboard press has
    // no finger, so the reference self-times the pressed state for the
    // fast step, 167 ms (hover_button.dart:243-251) - without this, an
    // Enter press would be invisible.
    await pumpFluentBehavior(tester, _button(onPressed: () {}));
    await focusWithTab(tester);
    final Color resting = containerFill(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Let the 83 ms container animation carry the fill to pressed.
    await tester.pump(const Duration(milliseconds: 83));
    expect(
      containerFill(tester).toARGB32(),
      // ControlFillColorTertiary, light: color_resources.dart:289.
      const Color(0x4df9f9f9).toARGB32(),
      reason: 'the flash must show the real pressed fill',
    );
    // 83 ms of the 167 ms flash have elapsed. Walk the clock in 10 ms
    // frames and record the FIRST frame whose fill has left the pressed
    // value - a single long pump would leave the 167 ms unmeasured,
    // because however early the flash ended, the reverse animation only
    // starts at that one frame and still paints pressed at progress zero
    // (the same near-vacuity the release-hold assertion once had).
    Duration elapsed = Duration.zero;
    Duration? firstMovedFrame;
    while (elapsed < const Duration(milliseconds: 300)) {
      await tester.pump(const Duration(milliseconds: 10));
      elapsed += const Duration(milliseconds: 10);
      if (containerFill(tester).toARGB32() !=
          const Color(0x4df9f9f9).toARGB32()) {
        firstMovedFrame = elapsed;
        break;
      }
    }
    // The flash self-times at 167 ms (hover_button.dart:243-251), 84 ms
    // after this walk begins; the retarget frame at 90 ms still paints
    // pressed at progress zero, so the first visibly moved frame at this
    // cadence is 100 ms in - earlier means the flash was cut short, later
    // means it overstays.
    expect(
      firstMovedFrame,
      const Duration(milliseconds: 100),
      reason: 'the flash must hold its full 167 ms, then let go on its own',
    );
    await tester.pumpAndSettle();
    expect(
      containerFill(tester).toARGB32(),
      resting.toARGB32(),
      reason: 'after the flash the button must rest again on its own',
    );
  });
}
