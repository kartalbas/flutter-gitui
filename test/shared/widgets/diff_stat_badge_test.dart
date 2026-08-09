/// The facade half of the paired-badge word (#438).
///
/// Material's answer to the pairing is pinned behaviourally in
/// `packages/gitui_skin_material/test/conformance/components/`
/// `badge_pairing_and_tag_removal_conformance_test.dart`; what remains on
/// this side of the seam is the translation `DiffStatBadge` performs - two
/// counts in the application's words becoming the contract's paired facts -
/// and that translation has its own edges: a one-sided stat is a single
/// fact rather than a pair padded with a zero, and a stat with nothing to
/// say renders nothing at all (the construction this replaced drew an empty
/// chip for a binary file, a surface standing for no fact).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/widgets/diff_stat_badge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../skin/pump_under_skin.dart';

void main() {
  testWidgets('a two-sided stat says both facts', (WidgetTester tester) async {
    await pumpUnderSkin(
      tester,
      home: const DiffStatBadge(additions: 12, deletions: 3),
    );

    expect(find.text('+12'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('a one-sided stat is a single fact, not a padded pair', (
    WidgetTester tester,
  ) async {
    await pumpUnderSkin(
      tester,
      home: const DiffStatBadge(additions: 12, deletions: 0),
    );

    expect(find.text('+12'), findsOneWidget);
    expect(
      find.text('-0'),
      findsNothing,
      reason:
          'A count of zero is not a fact; padding the pair with it would '
          'state a deletion that never happened.',
    );
  });

  testWidgets('a deletions-only stat leads with the deletion', (
    WidgetTester tester,
  ) async {
    await pumpUnderSkin(
      tester,
      home: const DiffStatBadge(additions: 0, deletions: 3),
    );

    expect(find.text('-3'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('a stat with nothing to say renders nothing', (
    WidgetTester tester,
  ) async {
    await pumpUnderSkin(
      tester,
      home: const DiffStatBadge(additions: 0, deletions: 0),
    );

    expect(
      find.byType(Text),
      findsNothing,
      reason:
          'The hand-painted construction drew an empty chip for a binary '
          'file - a surface standing for no fact - and the facade refuses '
          'to reproduce it.',
    );
  });
}
