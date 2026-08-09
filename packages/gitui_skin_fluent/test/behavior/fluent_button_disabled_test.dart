/// DISABLED, measured from the paint stream.
///
/// Behaviour 3 of the Fluent behaviour suite: which resources change when a
/// control is disabled, and - just as telling - which do NOT. Fluent keeps
/// a disabled control's geometry and outline and swaps only its fills and
/// text; and in the LIGHT theme an accent button's label famously does not
/// change at all (TextOnAccentFillColorDisabled is pure white, the dimming
/// lives entirely in the fill) while the DARK theme dims the label too.
/// Getting "which resources move" wrong is invisible in a screenshot diff
/// of one theme and glaring across both, which is why both are pinned.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';

import 'support/fluent_behavior_harness.dart';

Widget _standard({VoidCallback? onPressed}) => FluentButton(
  spec: ButtonSpec(
    label: 'Probe',
    emphasis: Emphasis.secondary,
    onPressed: onPressed,
  ),
);

Widget _accent({VoidCallback? onPressed}) => FluentButton(
  spec: ButtonSpec(
    label: 'Probe',
    emphasis: Emphasis.primary,
    onPressed: onPressed,
  ),
);

void main() {
  group('which resources change', () {
    testWidgets('standard, light: fill and label move to their Disabled '
        'resources', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _standard());
      expect(
        containerFill(tester).toARGB32(),
        // ControlFillColorDisabled, light: fluent_ui@4.16.1
        // color_resources.dart:291.
        const Color(0x4df9f9f9).toARGB32(),
      );
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        // TextFillColorDisabled, light: color_resources.dart:280.
        const Color(0x5c000000).toARGB32(),
      );
    });

    testWidgets('standard, dark: the same two resources, dark values', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _standard(),
        brightness: Brightness.dark,
      );
      expect(
        containerFill(tester).toARGB32(),
        // ControlFillColorDisabled, dark: color_resources.dart:204.
        const Color(0x0bffffff).toARGB32(),
      );
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        // TextFillColorDisabled, dark: color_resources.dart:193.
        const Color(0x5dffffff).toARGB32(),
      );
    });

    testWidgets('accent, light: the fill dims, the label does NOT', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _accent());
      expect(
        containerFill(tester).toARGB32(),
        // AccentFillColorDisabled, light: color_resources.dart:310.
        const Color(0x37000000).toARGB32(),
      );
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        // TextOnAccentFillColorDisabled, light: color_resources.dart:286 -
        // pure white, IDENTICAL to the enabled label (:284). The dimming
        // is the fill's job alone in light; a reimplementation that dims
        // both washes the label out twice.
        const Color(0xFFffffff).toARGB32(),
      );
    });

    testWidgets('accent, dark: the label DOES dim - the asymmetry is the '
        'specification', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _accent(), brightness: Brightness.dark);
      expect(
        containerFill(tester).toARGB32(),
        // AccentFillColorDisabled, dark: color_resources.dart:223.
        const Color(0x28ffffff).toARGB32(),
      );
      expect(
        renderedLabelColor(tester, 'Probe').toARGB32(),
        // TextOnAccentFillColorDisabled, dark: color_resources.dart:199 -
        // NOT the enabled black (:197).
        const Color(0x87ffffff).toARGB32(),
      );
    });
  });

  group('which resources do not change', () {
    testWidgets('the outline STAYS on a disabled standard button, as the '
        'flat default stroke', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _standard());
      final List<PaintedOutline> outlines = paintedOutlines(
        tester,
        buttonContainer(),
      );
      expect(
        outlines,
        hasLength(1),
        reason:
            'disabling must not erase the outline - Fluent draws a '
            'disabled control as a real control that cannot be used, not '
            'as a ghost',
      );
      expect(
        outlines.single.hasShader,
        isFalse,
        reason:
            'disabled shares the pressed state\'s FLAT stroke (fluent_ui '
            'buttons/theme.dart:331-335) - the elevation gradient is for '
            'controls that can still be pushed',
      );
      expect(
        outlines.single.color.toARGB32(),
        // ControlStrokeColorDefault, light: color_resources.dart:311.
        const Color(0x0f000000).toARGB32(),
      );
    });

    testWidgets('geometry is untouched: same box, same corner', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, _standard(onPressed: () {}));
      final Size enabledBox = tester.getSize(buttonContainer());
      final List<RRect> enabledRects = paintedRRects(tester, buttonContainer());
      expect(enabledRects, isNotEmpty);
      // The container fill paints the full shape: its radius IS the
      // control corner, 4 epx (WinUI ControlCornerRadius; fluent_ui
      // buttons/theme.dart:334).
      expect(enabledRects.first.tlRadiusX, 4.0);

      await pumpFluentBehavior(tester, _standard());
      expect(tester.getSize(buttonContainer()), enabledBox);
      final List<RRect> disabledRects = paintedRRects(
        tester,
        buttonContainer(),
      );
      expect(disabledRects, isNotEmpty);
      expect(disabledRects.first.tlRadiusX, 4.0);
    });
  });

  group('disabled answers nothing', () {
    testWidgets('hover changes no paint at all', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, _standard());
      final Color before = containerFill(tester);
      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(() => gesture.removePointer());
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(FluentButton)));
      await tester.pumpAndSettle();
      expect(
        containerFill(tester).toARGB32(),
        before.toARGB32(),
        reason:
            'a disabled control\'s state set is {disabled} and nothing '
            'else (hover_button.dart:295-303); a hover that still darkens '
            'the fill is answering input it promised not to answer',
      );
    });

    testWidgets('a press fires nothing and paints nothing', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      // Loading also disables - the contract's `isLoading` means "running,
      // hands off", so it must behave exactly like `onPressed: null`.
      await pumpFluentBehavior(
        tester,
        FluentButton(
          spec: ButtonSpec(
            label: 'Probe',
            emphasis: Emphasis.secondary,
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      final Color before = containerFill(tester);
      await tester.tap(find.byType(FluentButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pressed, 0);
      expect(containerFill(tester).toARGB32(), before.toARGB32());
    });

    testWidgets('Tab skips it and Enter cannot reach it', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await pumpFluentBehavior(tester, _standard(onPressed: null));
      await focusWithTab(tester);
      expect(
        paintedStrokes(tester, focusRingBox()),
        isEmpty,
        reason: 'a disabled control is not a Tab stop, so no rectangle',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(pressed, 0);
    });
  });
}
