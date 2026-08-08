// BaseShrinkingRow: children keep their natural width while they fit, only
// the widest shrink when they do not, an invisible child leaves no gap, and
// below the per-child floor the row clips at its own edge instead of painting
// over its neighbors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_shrinking_row.dart';
import '../../skin/pump_under_skin.dart';

Future<void> _pump(
  WidgetTester tester, {
  required double availableWidth,
  required BaseShrinkingRow row,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          installSkinUnderTest(child ?? const SizedBox.shrink()),

      home: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: availableWidth),
          child: row,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('children that fit keep their natural width and spacing', (
    tester,
  ) async {
    await _pump(
      tester,
      availableWidth: 400,
      row: const BaseShrinkingRow(
        spacing: 16,
        children: [
          SizedBox(key: Key('a'), width: 100, height: 20),
          SizedBox(key: Key('b'), width: 50, height: 20),
          SizedBox(key: Key('c'), width: 80, height: 20),
        ],
      ),
    );

    expect(tester.getSize(find.byKey(const Key('a'))).width, 100);
    expect(tester.getSize(find.byKey(const Key('b'))).width, 50);
    expect(tester.getSize(find.byKey(const Key('c'))).width, 80);
    // 100 + 16 + 50 + 16 + 80: the row hugs its content.
    expect(tester.getSize(find.byType(BaseShrinkingRow)).width, 262);
    expect(
      tester.getTopLeft(find.byKey(const Key('b'))).dx -
          tester.getTopRight(find.byKey(const Key('a'))).dx,
      16,
    );
  });

  testWidgets('a zero-width child takes no spacing either', (tester) async {
    await _pump(
      tester,
      availableWidth: 400,
      row: const BaseShrinkingRow(
        spacing: 16,
        children: [
          SizedBox(key: Key('a'), width: 100, height: 20),
          SizedBox.shrink(key: Key('hidden')),
          SizedBox(key: Key('c'), width: 80, height: 20),
        ],
      ),
    );

    // 100 + 16 + 80: one gap, not the two a plain Row with fixed SizedBox
    // spacers would leave around the invisible child.
    expect(tester.getSize(find.byType(BaseShrinkingRow)).width, 196);
    expect(
      tester.getTopLeft(find.byKey(const Key('c'))).dx -
          tester.getTopRight(find.byKey(const Key('a'))).dx,
      16,
    );
  });

  testWidgets('over budget, only the widest children shrink', (tester) async {
    await _pump(
      tester,
      availableWidth: 400,
      row: const BaseShrinkingRow(
        spacing: 10,
        children: [
          SizedBox(key: Key('a'), width: 100, height: 20),
          SizedBox(key: Key('b'), width: 300, height: 20),
          SizedBox(key: Key('c'), width: 120, height: 20),
        ],
      ),
    );

    // Budget is 400 - 2*10 = 380 for 100+300+120 = 520 of content. The water
    // fill keeps the 100 and 120 children whole and gives the 300 child the
    // remaining 160; a flex row would have squeezed all three to ~127.
    expect(tester.getSize(find.byKey(const Key('a'))).width, 100);
    expect(tester.getSize(find.byKey(const Key('b'))).width, 160);
    expect(tester.getSize(find.byKey(const Key('c'))).width, 120);
    expect(tester.getSize(find.byType(BaseShrinkingRow)).width, 400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('below the floor the row clips instead of squeezing further', (
    tester,
  ) async {
    await _pump(
      tester,
      availableWidth: 150,
      row: const BaseShrinkingRow(
        spacing: 10,
        minChildWidth: 90,
        children: [
          SizedBox(key: Key('a'), width: 300, height: 20),
          SizedBox(key: Key('b'), width: 300, height: 20),
        ],
      ),
    );

    // Each child stops at the 90px floor; the row itself respects its
    // constraint and clips the 40px that no longer fit.
    expect(tester.getSize(find.byKey(const Key('a'))).width, 90);
    expect(tester.getSize(find.byKey(const Key('b'))).width, 90);
    expect(tester.getSize(find.byType(BaseShrinkingRow)).width, 150);
    expect(tester.takeException(), isNull);
  });
}
