// BaseDropdownButton and BaseSwitch honor every parameter they accept:
// a tooltip passed to the dropdown is actually shown, and the switch applies
// the caller's colors per state — the active colors only while selected, the
// inactive colors only while unselected, and neither while disabled, so the
// theme keeps its disabled treatment.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_animated_widgets.dart';

void main() {
  group('BaseDropdownButton', () {
    Future<void> pumpDropdown(WidgetTester tester, {String? tooltip}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BaseDropdownButton<int>(
              value: 1,
              items: const [
                DropdownMenuItem(value: 1, child: Text('One')),
                DropdownMenuItem(value: 2, child: Text('Two')),
              ],
              onChanged: (_) {},
              tooltip: tooltip,
            ),
          ),
        ),
      );
    }

    testWidgets('shows the tooltip that is passed', (tester) async {
      await pumpDropdown(tester, tooltip: 'Pick a number');

      expect(find.byTooltip('Pick a number'), findsOneWidget);
    });

    testWidgets('adds no tooltip wrapper when none is passed', (tester) async {
      await pumpDropdown(tester);

      expect(find.byType(Tooltip), findsNothing);
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
