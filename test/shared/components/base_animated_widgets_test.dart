// BaseSwitch honors every parameter it accepts: the caller's colors are
// applied per state — the active colors only while selected, the inactive
// colors only while unselected, and neither while disabled, so the theme
// keeps its disabled treatment.
//
// A `BaseDropdownButton` group stood beside this one and asked whether that
// widget honored the tooltip it was passed. Its subject is gone — no call
// site anywhere in `lib/`, deleted rather than converted (see the note where
// it stood in base_animated_widgets.dart) — but the premise did not leave
// with it: "a façade in this file must never cost its trigger the accessible
// name" is exactly as true of `BasePopupMenuButton`, the file's surviving
// façade with the same `tooltip` parameter and two live callers. The group
// below is that premise re-aimed at the surviving subject, per the rule that
// a test whose subject dies is rewritten onto what still matters, never
// deleted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_animated_widgets.dart';
import '../../skin/pump_under_skin.dart';

void main() {
  group('BasePopupMenuButton', () {
    Future<void> pumpButton(WidgetTester tester, {String? tooltip}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: BasePopupMenuButton<int>(
              tooltip: tooltip,
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<int>>[
                    PopupMenuItem<int>(value: 1, child: Text('One')),
                  ],
            ),
          ),
        ),
      );
    }

    testWidgets('shows the tooltip that is passed', (tester) async {
      await pumpButton(tester, tooltip: 'Open quick settings');

      expect(find.byTooltip('Open quick settings'), findsOneWidget);
    });

    testWidgets('keeps an accessible name when no tooltip is passed: the '
        'trigger falls back to Material\'s own menu name', (tester) async {
      await pumpButton(tester);

      // The façade forwards null rather than inventing a name of its own...
      final button = tester.widget<PopupMenuButton<int>>(
        find.byType(PopupMenuButton<int>),
      );
      expect(button.tooltip, isNull);
      // ...and the icon-only trigger still carries Material's stock name, so
      // no caller can produce a nameless control through this façade.
      expect(find.byTooltip('Show menu'), findsOneWidget);
    });
  });

  group('BaseSwitch', () {
    const activeThumb = Color(0xFF00FF00);
    const activeTrack = Color(0xFF008800);
    const inactiveThumb = Color(0xFFFF0000);
    const inactiveTrack = Color(0xFF880000);

    Future<Switch> pumpSwitch(
      WidgetTester tester, {
      Color? activeThumbColor,
      Color? activeTrackColor,
      Color? inactiveThumbColor,
      Color? inactiveTrackColor,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: BaseSwitch(
              value: false,
              onChanged: (_) {},
              activeThumbColor: activeThumbColor,
              activeTrackColor: activeTrackColor,
              inactiveThumbColor: inactiveThumbColor,
              inactiveTrackColor: inactiveTrackColor,
            ),
          ),
        ),
      );
      return tester.widget<Switch>(find.byType(Switch));
    }

    testWidgets('applies the active colors only while selected', (
      tester,
    ) async {
      final switchWidget = await pumpSwitch(
        tester,
        activeThumbColor: activeThumb,
        activeTrackColor: activeTrack,
        inactiveThumbColor: inactiveThumb,
        inactiveTrackColor: inactiveTrack,
      );

      final selected = {WidgetState.selected};
      expect(switchWidget.thumbColor!.resolve(selected), activeThumb);
      expect(switchWidget.trackColor!.resolve(selected), activeTrack);
    });

    testWidgets('an inactive switch gets the inactive colors, not the active '
        'ones', (tester) async {
      final switchWidget = await pumpSwitch(
        tester,
        activeThumbColor: activeThumb,
        activeTrackColor: activeTrack,
        inactiveThumbColor: inactiveThumb,
        inactiveTrackColor: inactiveTrack,
      );

      final unselected = <WidgetState>{};
      expect(switchWidget.thumbColor!.resolve(unselected), inactiveThumb);
      expect(switchWidget.trackColor!.resolve(unselected), inactiveTrack);
    });

    testWidgets('an inactive switch is not tinted when only active colors are '
        'given', (tester) async {
      // Regression: the active colors used to be applied through
      // WidgetStateProperty.all, tinting the inactive state too.
      final switchWidget = await pumpSwitch(
        tester,
        activeThumbColor: activeThumb,
        activeTrackColor: activeTrack,
      );

      final unselected = <WidgetState>{};
      expect(switchWidget.thumbColor!.resolve(unselected), isNull);
      expect(switchWidget.trackColor!.resolve(unselected), isNull);
    });

    testWidgets('a disabled switch falls back to the theme treatment', (
      tester,
    ) async {
      final switchWidget = await pumpSwitch(
        tester,
        activeThumbColor: activeThumb,
        activeTrackColor: activeTrack,
        inactiveThumbColor: inactiveThumb,
        inactiveTrackColor: inactiveTrack,
      );

      final disabled = {WidgetState.disabled};
      expect(switchWidget.thumbColor!.resolve(disabled), isNull);
      expect(switchWidget.trackColor!.resolve(disabled), isNull);
    });

    testWidgets('leaves the theme in control when no colors are given', (
      tester,
    ) async {
      final switchWidget = await pumpSwitch(tester);

      expect(switchWidget.thumbColor, isNull);
      expect(switchWidget.trackColor, isNull);
    });
  });
}
