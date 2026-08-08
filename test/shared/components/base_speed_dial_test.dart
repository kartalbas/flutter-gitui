// BaseSpeedDial behaviour: collapsed shows only the main FAB, expanded shows
// every action with its label, the main FAB reports a toggle to the parent,
// and tapping an action fires its own callback and asks the parent to
// collapse the dial.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_speed_dial.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import '../../skin/pump_under_skin.dart';

Future<void> _pumpDial(
  WidgetTester tester, {
  required List<SpeedDialAction> actions,
  required bool isExpanded,
  VoidCallback? onToggle,
  VoidCallback? onCollapse,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          installSkinUnderTest(child ?? const SizedBox.shrink()),

      // The dial's own button names the next press ("Expand"/"Collapse") in
      // the user's language, so it reads AppLocalizations and needs the app's
      // delegates here just as every screen supplies them.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

  // The drag clamp derives from the dial's rendered size plus the standard
  // AppTheme.paddingM edge margin, so the whole dial stays visible however
  // far it is dragged toward any screen edge.
  testWidgets('dragging far past the top-left keeps the whole collapsed dial '
      'inside the viewport with the standard margin', (tester) async {
    await _pumpDial(tester, actions: actions, isExpanded: false);

    await tester.drag(
      find.byType(FloatingActionButton),
      const Offset(-10000, -10000),
    );
    await tester.pump();

    final fabRect = tester.getRect(find.byType(FloatingActionButton));
    expect(fabRect.left, AppTheme.paddingM);
    expect(fabRect.top, AppTheme.paddingM);
  });

  testWidgets('dragging far past the bottom-right keeps the standard margin '
      'to those edges', (tester) async {
    await _pumpDial(tester, actions: actions, isExpanded: false);

    await tester.drag(
      find.byType(FloatingActionButton),
      const Offset(10000, 10000),
    );
    await tester.pump();

    final viewport = tester.getSize(find.byType(Scaffold));
    final fabRect = tester.getRect(find.byType(FloatingActionButton));
    expect(fabRect.right, viewport.width - AppTheme.paddingM);
    expect(fabRect.bottom, viewport.height - AppTheme.paddingM);
  });

  testWidgets('dragging the expanded dial keeps every action and label on '
      'screen', (tester) async {
    await _pumpDial(tester, actions: actions, isExpanded: true);

    // Drag from the main FAB (the last button in the column).
    await tester.drag(
      find.byType(FloatingActionButton).last,
      const Offset(-10000, -10000),
    );
    await tester.pump();

    final viewport = tester.getSize(find.byType(Scaffold));
    final dialRect = tester.getRect(find.byType(BaseSpeedDial));
    expect(dialRect.left, AppTheme.paddingM);
    expect(dialRect.top, AppTheme.paddingM);
    expect(dialRect.right, lessThanOrEqualTo(viewport.width));
    expect(dialRect.bottom, lessThanOrEqualTo(viewport.height));
  });

  testWidgets('two dials on one route survive a route transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
