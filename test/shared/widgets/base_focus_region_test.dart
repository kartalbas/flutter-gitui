// The focus-region system the app shell is built on (#290): regions form one
// Tab cycle in their declared numeric order, F6/Shift+F6 jump between them as
// panes, and the host's anchor takes focus only when nothing inside claims
// it — while never being a Tab stop itself.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_gitui/shared/widgets/base_focus_region.dart';

Widget _stop(String label) => Focus(
  debugLabel: label,
  child: const SizedBox(width: AppTheme.paddingL, height: AppTheme.paddingL),
);

/// Three regions declared out of numeric order on purpose: the Tab and F6
/// cycles must follow the declared order, not the build order.
List<Widget> _threeRegions() => [
  BaseFocusRegion(
    order: 2,
    debugLabel: 'region.middle',
    child: Column(children: [_stop('middle.first'), _stop('middle.second')]),
  ),
  BaseFocusRegion(
    order: 3,
    debugLabel: 'region.last',
    child: Column(children: [_stop('last.only')]),
  ),
  BaseFocusRegion(
    order: 1,
    debugLabel: 'region.first',
    child: Column(children: [_stop('first.first'), _stop('first.second')]),
  ),
];

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<Widget> regions,
  Map<ShortcutActivator, VoidCallback>? shortcuts,
}) async {
  Widget child = BaseFocusRegionHost(
    debugLabel: 'host.anchor',
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: regions),
  );
  if (shortcuts != null) {
    child = CallbackShortcuts(bindings: shortcuts, child: child);
  }
  await tester.pumpWidget(MaterialApp(home: child));
  // The host decides on its focus of last resort on the frame after the
  // autofocus pipeline settled; give it those frames.
  await tester.pump();
  await tester.pump();
}

Future<void> _tab(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> _f6(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.f6);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  group('Tab order across regions', () {
    testWidgets(
      'Tab walks the regions in declared numeric order, reading order '
      'inside each, and never stops on the anchor',
      (tester) async {
        await _pumpHost(tester, regions: _threeRegions());

        final visited = <String>[];
        for (var i = 0; i < 7; i++) {
          await _tab(tester);
          visited.add(primaryFocus!.debugLabel!);
        }

        expect(visited, [
          'first.first',
          'first.second',
          'middle.first',
          'middle.second',
          'last.only',
          'first.first',
          'first.second',
        ]);
      },
    );

    testWidgets('Shift+Tab walks the same cycle backwards', (tester) async {
      await _pumpHost(tester, regions: _threeRegions());

      await _tab(tester);
      expect(primaryFocus!.debugLabel, 'first.first');

      // Backwards from the first stop wraps to the last region's last stop.
      await _tab(tester, shift: true);
      expect(primaryFocus!.debugLabel, 'last.only');

      await _tab(tester, shift: true);
      expect(primaryFocus!.debugLabel, 'middle.second');
    });
  });

  group('F6 pane cycling', () {
    testWidgets(
      'F6 enters the next region at its first control from anywhere in the '
      'current one; Shift+F6 cycles backwards; both wrap',
      (tester) async {
        await _pumpHost(tester, regions: _threeRegions());

        // Stand on the SECOND control of region one, so the landing spot
        // proves F6 targets the next region's first control.
        await _tab(tester);
        await _tab(tester);
        expect(primaryFocus!.debugLabel, 'first.second');

        await _f6(tester);
        expect(primaryFocus!.debugLabel, 'middle.first');

        await _f6(tester);
        expect(primaryFocus!.debugLabel, 'last.only');

        await _f6(tester);
        expect(primaryFocus!.debugLabel, 'first.first');

        await _f6(tester, shift: true);
        expect(primaryFocus!.debugLabel, 'last.only');

        await _f6(tester, shift: true);
        expect(primaryFocus!.debugLabel, 'middle.first');
      },
    );

    testWidgets('a region with nothing focusable is skipped', (tester) async {
      await _pumpHost(
        tester,
        regions: [
          BaseFocusRegion(
            order: 1,
            debugLabel: 'region.first',
            child: Column(children: [_stop('a')]),
          ),
          const BaseFocusRegion(
            order: 2,
            debugLabel: 'region.empty',
            child: SizedBox(
              width: AppTheme.paddingL,
              height: AppTheme.paddingL,
            ),
          ),
          BaseFocusRegion(
            order: 3,
            debugLabel: 'region.last',
            child: Column(children: [_stop('c')]),
          ),
        ],
      );

      await _tab(tester);
      expect(primaryFocus!.debugLabel, 'a');

      await _f6(tester);
      expect(primaryFocus!.debugLabel, 'c');

      await _f6(tester);
      expect(primaryFocus!.debugLabel, 'a');
    });
  });

  group('focus of last resort', () {
    testWidgets('a descendant autofocus claim beats the host anchor', (
      tester,
    ) async {
      await _pumpHost(
        tester,
        regions: [
          BaseFocusRegion(
            order: 1,
            debugLabel: 'region.first',
            child: Column(children: [_stop('plain')]),
          ),
          BaseFocusRegion(
            order: 2,
            debugLabel: 'region.second',
            child: Column(
              children: [
                Focus(
                  debugLabel: 'screen.claimant',
                  autofocus: true,
                  child: const SizedBox(
                    width: AppTheme.paddingL,
                    height: AppTheme.paddingL,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      // The screen's claim stands even though the host, as an ancestor, was
      // built first — the bug the deferred anchor removes.
      expect(primaryFocus!.debugLabel, 'screen.claimant');

      // And the host keeps standing down on later frames.
      await tester.pump();
      expect(primaryFocus!.debugLabel, 'screen.claimant');
    });

    testWidgets(
      'without a claim the host holds focus, so app-level shortcuts above '
      'it fire from the start and keep firing inside a region',
      (tester) async {
        var fired = 0;
        await _pumpHost(
          tester,
          regions: _threeRegions(),
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.keyM, control: true): () =>
                fired++,
          },
        );

        expect(primaryFocus?.debugLabel, 'host.anchor');
        await _ctrl(tester, LogicalKeyboardKey.keyM);
        expect(fired, 1);

        // Moving into a region keeps the same shortcuts working: key events
        // bubble through the host to the bindings above it.
        await _tab(tester);
        expect(primaryFocus!.debugLabel, 'first.first');
        await _ctrl(tester, LogicalKeyboardKey.keyM);
        expect(fired, 2);
      },
    );
  });
}
