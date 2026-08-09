/// MOTION, measured frame by frame.
///
/// Behaviour 4 of the Fluent behaviour suite: that a state change is
/// ANIMATED at all, and how long it takes. A drawn control that snaps
/// between its state fills has the right colours and the wrong feel; one
/// that animates at Material's 200 ms has the wrong feel in the other
/// direction. WinUI's control step is 83 ms
/// (`ControlFasterAnimationDuration`; fluent_ui@4.16.1
/// lib/src/styles/theme.dart:440) on an ease-in-out curve (theme.dart:197),
/// with TEXT following one step slower at 167 ms
/// (buttons/base.dart:231-232) - and a pointer release holds the pressed
/// state 100 ms before letting go (hover_button.dart:316-321). Each of
/// those is bounded here by pumping exact durations and reading the fill
/// mid-flight.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';

import 'support/fluent_behavior_harness.dart';

// ControlFillColorDefault / Secondary / Tertiary, light theme
// (fluent_ui@4.16.1 color_resources.dart:287-289).
const Color _rest = Color(0xb3ffffff);
const Color _hover = Color(0x80f9f9f9);
const Color _pressed = Color(0x4df9f9f9);

// TextFillColorPrimary / Secondary, light theme (color_resources.dart:277,
// :278).
const Color _labelRest = Color(0xe4000000);
const Color _labelPressed = Color(0x9e000000);

Widget _button() => FluentButton(
  spec: ButtonSpec(
    label: 'Probe',
    emphasis: Emphasis.secondary,
    onPressed: () {},
  ),
);

void main() {
  testWidgets('hover is ANIMATED: still resting at the first frame, '
      'mid-flight before 83 ms, arrived at 83 ms', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button());
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(FluentButton)));
    // Frame zero of the transition: the animation has begun but no time
    // has passed, so the fill must STILL be the resting one. A snapping
    // implementation fails exactly here.
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(
      containerFill(tester).toARGB32(),
      _rest.toARGB32(),
      reason:
          'a state change must ANIMATE from the old fill, not snap '
          '(fluent_ui buttons/base.dart:218-221: an AnimatedContainer at '
          'the faster step, not a rebuilt colour)',
    );
    // 41 ms in: mid-flight, equal to NEITHER endpoint. This also bounds
    // the duration from below - an animation faster than 41 ms would have
    // arrived already.
    await tester.pump(const Duration(milliseconds: 41));
    final Color midFlight = containerFill(tester);
    expect(midFlight.toARGB32(), isNot(_rest.toARGB32()));
    expect(midFlight.toARGB32(), isNot(_hover.toARGB32()));
    // 83 ms total: arrived exactly. Bounds the duration from above at the
    // published ControlFasterAnimationDuration (theme.dart:440).
    await tester.pump(const Duration(milliseconds: 42));
    expect(
      containerFill(tester).toARGB32(),
      _hover.toARGB32(),
      reason: 'the container transition is 83 ms, no slower',
    );
  });

  testWidgets('text follows its container one step behind: container 83 ms, '
      'label 167 ms', (WidgetTester tester) async {
    // The two-speed answer is the reference\'s own
    // (buttons/base.dart:218-238: container at fasterAnimationDuration,
    // AnimatedDefaultTextStyle at fastAnimationDuration): the box reacts
    // first, the words settle after.
    await pumpFluentBehavior(tester, _button());
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(FluentButton)),
    );
    await tester.pump();
    // 100 ms in: past the container's 83 ms, inside the label's 167 ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      containerFill(tester).toARGB32(),
      _pressed.toARGB32(),
      reason: 'the container must have arrived by 100 ms',
    );
    final Color labelMidFlight = renderedLabelColor(tester, 'Probe');
    expect(
      labelMidFlight.toARGB32(),
      isNot(_labelRest.toARGB32()),
      reason: 'the label must have started moving',
    );
    expect(
      labelMidFlight.toARGB32(),
      isNot(_labelPressed.toARGB32()),
      reason: 'the label must not have arrived yet at 100 ms of its 167',
    );
    // Run out the label's remaining 67 ms.
    await tester.pump(const Duration(milliseconds: 67));
    expect(
      renderedLabelColor(tester, 'Probe').toARGB32(),
      _labelPressed.toARGB32(),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('release holds the pressed state 100 ms so a fast click is '
      'still seen', (WidgetTester tester) async {
    await pumpFluentBehavior(tester, _button());
    final TestGesture gesture = await pressAndHold(
      tester,
      find.byType(FluentButton),
    );
    expect(containerFill(tester).toARGB32(), _pressed.toARGB32());
    await gesture.up();
    // The release frame itself: the hold has only just begun.
    await tester.pump();
    expect(containerFill(tester).toARGB32(), _pressed.toARGB32());
    // Walk the clock in 10 ms frames and record the FIRST frame whose fill
    // has left the pressed value. A single long pump here proves nothing:
    // however early the hold ended, the reverse animation only STARTS at
    // that one frame and still paints the pressed fill at progress zero -
    // which is exactly how this assertion was once vacuous, passing with
    // the hold shortened to 10 ms and with the hold deleted outright.
    Duration elapsed = Duration.zero;
    Duration? firstMovedFrame;
    while (elapsed < const Duration(milliseconds: 300)) {
      await tester.pump(const Duration(milliseconds: 10));
      elapsed += const Duration(milliseconds: 10);
      if (containerFill(tester).toARGB32() != _pressed.toARGB32()) {
        firstMovedFrame = elapsed;
        break;
      }
    }
    // The hold ends at 100 ms (hover_button.dart:316-321). The 100 ms
    // retarget frame still paints pressed at progress zero, so the first
    // visibly moved frame at this cadence is 110 ms - earlier means the
    // hold was cut short, later means it overstays.
    expect(
      firstMovedFrame,
      const Duration(milliseconds: 110),
      reason:
          'the pressed state must survive the release for exactly the '
          '100 ms hold - without the hold, a click faster than the 83 ms '
          'animation would never show its press at all',
    );
    // Run out the 83 ms animation back to rest.
    await tester.pumpAndSettle();
    expect(containerFill(tester).toARGB32(), _rest.toARGB32());
  });
}
