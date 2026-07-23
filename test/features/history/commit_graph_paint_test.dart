// The graph painter draws with colors resolved outside the widget tree, so
// no pure lane test would notice a paint-time failure. Pumping real rows,
// selection included, under both themes is what keeps the overlay honest.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/features/history/models/commit_graph.dart';
import 'package:flutter_gitui/features/history/widgets/commit_list_item.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

GitCommit commit(String hash, {List<String> parents = const []}) {
  final when = DateTime.utc(2026);
  return GitCommit(
    hash: hash,
    shortHash: hash,
    author: 'a',
    authorEmail: 'a@example.com',
    authorDate: when,
    committer: 'a',
    committerEmail: 'a@example.com',
    committerDate: when,
    subject: 'subject',
    body: '',
    parents: parents,
    refs: const [],
  );
}

void main() {
  testWidgets('graph rows paint in light and dark themes', (tester) async {
    final commits = [
      commit('m', parents: ['a', 'b']),
      commit('a', parents: ['c']),
      commit('b', parents: ['c']),
      commit('c'),
    ];
    final graph = CommitGraph.fromCommits(commits);

    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(
                children: [
                  for (final c in commits)
                    CommitListItem(
                      commit: c,
                      isSelected: c.hash == 'a',
                      onTap: () {},
                      graphRow: graph.rowFor(c.hash),
                      graphLaneCount: graph.laneCount,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    }

    // Drain timers scheduled by font loading so teardown sees none pending.
    await tester.pump(const Duration(seconds: 30));
  });
}
