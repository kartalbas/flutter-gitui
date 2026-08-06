// BaseSpeedDial behaviour: collapsed shows only the main FAB, expanded shows
// every action with its label, the main FAB reports a toggle to the parent,
// and tapping an action fires its own callback and asks the parent to
// collapse the dial.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_speed_dial.dart';

Future<void> _pumpDial(
  WidgetTester tester, {
  required List<SpeedDialAction> actions,
  required bool isExpanded,
  VoidCallback? onToggle,
  VoidCallback? onCollapse,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            BaseSpeedDial(
              actions: actions,
              isExpanded: isExpanded,
              onToggle: onToggle ?? () {},
              onCollapse: onCollapse ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final actions = [
    SpeedDialAction(icon: Icons.copy, label: 'Copy', onPressed: () {}),
    SpeedDialAction(icon: Icons.share, label: 'Share', onPressed: () {}),
  ];

  testWidgets('renders every action with its label when expanded', (
    tester,
  ) async {
    await _pumpDial(tester, actions: actions, isExpanded: true);

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    // One mini FAB per action plus the main FAB.
    expect(find.byType(FloatingActionButton), findsNWidgets(3));
  });

  testWidgets('renders no actions when collapsed', (tester) async {
    await _pumpDial(tester, actions: actions, isExpanded: false);

    expect(find.text('Copy'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.byIcon(Icons.copy), findsNothing);
    expect(find.byIcon(Icons.share), findsNothing);
    // Only the main FAB remains.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('calls onToggle when the main button is tapped', (tester) async {
    var toggleCount = 0;
    await _pumpDial(
      tester,
      actions: actions,
      isExpanded: false,
      onToggle: () => toggleCount++,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(toggleCount, 1);
  });

  testWidgets('calls the action callback and onCollapse when an action is '
      'tapped', (tester) async {
    var copyPressed = 0;
    var collapseCount = 0;
    var toggleCount = 0;
    await _pumpDial(
      tester,
      actions: [
        SpeedDialAction(
          icon: Icons.copy,
          label: 'Copy',
          onPressed: () => copyPressed++,
        ),
      ],
      isExpanded: true,
      onToggle: () => toggleCount++,
      onCollapse: () => collapseCount++,
    );

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(copyPressed, 1);
    expect(collapseCount, 1);
    expect(toggleCount, 0);
  });

  // Flutter throws when two heroes in one route share a tag. The buttons here
  // carried the action's localized label as their tag, and the main button a
  // shared string literal, so both collisions were reachable without anyone
  // touching this widget: a translation could make two labels equal, and a
  // screen showing its own dial while a diff viewer is open would have had two
  // main buttons on one route.
  // A duplicate hero tag is only detected while a route transition builds its
  // flight manifest, so these tests must actually navigate. Asserting on a
  // freshly pumped tree would pass whether or not the tags are unique, which
  // is worse than having no test at all.
  Future<void> pushARoute(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('two actions with the same label survive a route transition', (
    tester,
  ) async {
    await _pumpDial(
      tester,
      actions: [
        SpeedDialAction(icon: Icons.copy, label: 'Copy', onPressed: () {}),
        SpeedDialAction(icon: Icons.share, label: 'Copy', onPressed: () {}),
      ],
      isExpanded: true,
    );

    await pushARoute(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('two dials on one route survive a route transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              BaseSpeedDial(
                actions: actions,
                isExpanded: true,
                onToggle: () {},
                onCollapse: () {},
              ),
              BaseSpeedDial(
                actions: actions,
                isExpanded: true,
                onToggle: () {},
                onCollapse: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await pushARoute(tester);

    expect(tester.takeException(), isNull);
  });
}
