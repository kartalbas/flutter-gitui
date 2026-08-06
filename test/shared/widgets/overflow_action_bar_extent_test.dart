// The bar's arithmetic in visibleActionCount assumes every slot is
// OverflowActionBar.itemExtent wide, including the slot it reserves for the
// overflow menu button. If the rendered widths disagree with that assumption
// the bar overflows its parent, which is invisible until something gives it a
// tight budget.
//
// These tests pin the two widths the arithmetic depends on, so a change to
// either the icon button or the popup menu button fails here rather than as a
// yellow-and-black stripe on a narrow window.

import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/widgets/overflow_action_bar.dart';
import 'package:flutter_test/flutter_test.dart';

ToolbarAction _action(int index) => ToolbarAction(
  icon: PhosphorIconsRegular.gitBranch,
  label: 'Action $index',
  tooltip: 'Action $index',
  onPressed: () {},
);

Future<void> _pumpBar(
  WidgetTester tester, {
  required int actionCount,
  required double width,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            // A loose ceiling, not a fixed width: SizedBox would tighten the
            // constraint and force the bar to that width, hiding what it
            // actually drew.
            constraints: BoxConstraints(maxWidth: width),
            child: OverflowActionBar(
              actions: [for (var i = 0; i < actionCount; i++) _action(i)],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// The bar fills the width it is given, so its own box says nothing about
  /// what it drew. The inner Row is the rendered content.
  Finder barContent() => find.descendant(
    of: find.byType(OverflowActionBar),
    matching: find.byType(Row),
  );

  testWidgets('one action occupies exactly one item extent', (tester) async {
    await _pumpBar(tester, actionCount: 1, width: 400);

    expect(
      tester.getSize(barContent()).width,
      OverflowActionBar.itemExtent,
      reason:
          'A single action must occupy exactly itemExtent, otherwise every '
          'width the bar computes is wrong.',
    );
  });

  testWidgets('the overflow menu button occupies menuExtent', (tester) async {
    // A budget of exactly menuExtent leaves room for the menu button alone, so
    // the rendered content is that button and nothing else.
    await _pumpBar(tester, actionCount: 6, width: OverflowActionBar.menuExtent);

    expect(
      tester.getSize(barContent()).width,
      OverflowActionBar.menuExtent,
      reason:
          'visibleActionCount reserves menuExtent for the overflow button. A '
          'button wider than that makes the bar overflow its parent.',
    );
  });

  testWidgets('the bar never exceeds the width it was given', (tester) async {
    // Every width from "only the menu fits" up to "everything fits", so a
    // mismatch at any intermediate step is caught rather than only at the ends.
    // Starts at menuExtent: below that not even the overflow button fits, and
    // callers are expected never to hand the bar less than that.
    for (var width = OverflowActionBar.menuExtent; width <= 320; width += 7) {
      await _pumpBar(tester, actionCount: 7, width: width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the bar overflowed at width $width',
      );
      expect(
        tester.getSize(find.byType(OverflowActionBar)).width,
        lessThanOrEqualTo(width),
        reason: 'the bar rendered wider than its $width budget',
      );
    }
  });
}
