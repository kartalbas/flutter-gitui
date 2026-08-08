// The history screen on the shared keyboard navigation (#290): the commit
// list's highlight is the one selection in commitSelectionProvider, driven in
// delegated mode, so arrows move the selection the details panel follows;
// pushing against the loaded window's edge pages through the same loadMore
// the footer button invokes; and Escape walks the ladder — collapse the
// expanded speed dial, clear the search, leave deep-search mode, then
// nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/file_change.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/history/history_screen.dart';
import 'package:flutter_gitui/features/history/models/history_search_filter.dart';
import 'package:flutter_gitui/features/history/providers/history_deep_search_provider.dart';
import 'package:flutter_gitui/features/history/providers/history_search_provider.dart';
import 'package:flutter_gitui/features/history/widgets/commit_details_panel.dart';
import 'package:flutter_gitui/features/history/widgets/deep_search_states.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

import 'support/scripted_git_service.dart';
import '../../skin/pump_under_skin.dart';

/// The scripted service with the non-log calls the screen's panels make
/// stubbed out, so no test ever shells out to git.
class _HistoryGitService extends ScriptedGitService {
  _HistoryGitService(super.onGetLog, {super.onSearchLog});

  @override
  Future<List<FileChange>> getCommitChangedFiles(String commitHash) async =>
      const [];
}

/// A commit whose message names its hash, so asserting what the details
/// panel shows identifies exactly which commit the highlight reached.
GitCommit _commit(String hash, {List<String> parents = const []}) =>
    commit(hash, subject: 'message for $hash', parents: parents);

Future<void> _pumpHistory(
  WidgetTester tester, {
  required _HistoryGitService service,
  required List<GitCommit> firstPage,
  int pageSize = 10,
}) async {
  // The three-column layout needs generous desktop width (the list footer
  // alone needs ~560px of the left column); overflow would fail the test
  // with layout exceptions instead of exercising the keyboard.
  tester.view.physicalSize = const Size(2800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
        gitServiceProvider.overrideWith((ref) => service),
        defaultCommitLimitProvider.overrideWith((ref) => pageSize),
        commitHistoryProvider.overrideWith((ref) async => firstPage),
        currentBranchProvider.overrideWith((ref) async => 'main'),
      ],
      child: MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The message the details panel shows for [hash], scoped to the panel so a
/// list row with the same text can never satisfy the assertion.
Finder _detailsShowing(String hash) => find.descendant(
  of: find.byType(CommitDetailsPanel),
  matching: find.text('message for $hash'),
);

void main() {
  testWidgets(
    'three ArrowDowns move the selection and the details panel shows the '
    'fourth commit',
    (tester) async {
      final service = _HistoryGitService(
        ({limit, branch, filePath, startPoints = const <String>[]}) async =>
            const Success(<GitCommit>[]),
      );
      await _pumpHistory(
        tester,
        service: service,
        firstPage: [
          _commit('c1', parents: ['c2']),
          _commit('c2', parents: ['c3']),
          _commit('c3', parents: ['c4']),
          _commit('c4', parents: ['c5']),
          _commit('c5'),
        ],
      );

      // The newest commit is highlighted from the start and the details
      // panel already follows it.
      expect(_detailsShowing('c1'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      expect(_detailsShowing('c4'), findsOneWidget);
      expect(_detailsShowing('c1'), findsNothing);
    },
  );

  testWidgets('End at the window edge pages via loadMore', (tester) async {
    final service = _HistoryGitService(({
      limit,
      branch,
      filePath,
      startPoints = const <String>[],
    }) async {
      // Only the cursor walk from the boundary returns the second page.
      if (startPoints.isEmpty) return const Success(<GitCommit>[]);
      return Success([
        _commit('c3', parents: ['c4']),
        _commit('c4'),
      ]);
    });
    await _pumpHistory(
      tester,
      service: service,
      pageSize: 2,
      firstPage: [
        _commit('c1', parents: ['c2']),
        _commit('c2', parents: ['c3']),
      ],
    );

    // First End lands on the last loaded commit; the edge is not crossed.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(_detailsShowing('c2'), findsOneWidget);
    expect(service.lastStartPoints, anyOf(isNull, isEmpty));

    // End again pushes against the edge: the next page is requested from
    // the window's boundary and the older commits appear in the list.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(service.lastStartPoints, ['c3']);
    expect(find.text('c4'), findsOneWidget);

    // The selection stayed on the row the user was on; the next End walks
    // into the newly loaded page.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(_detailsShowing('c4'), findsOneWidget);
  });

  testWidgets('Escape collapses the dial, then clears the search (leaving deep '
      'search with it), then does nothing', (tester) async {
    final service = _HistoryGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) async =>
          Success([commit('m1', subject: 'fix the parser')]),
    );
    await _pumpHistory(
      tester,
      service: service,
      pageSize: 2,
      firstPage: [
        commit('c1', subject: 'fix something', parents: ['c2']),
        commit('c2', subject: 'unrelated', parents: ['c3']),
      ],
    );

    // Type a query and let the debounce apply it.
    await tester.enterText(find.byType(TextField), 'fix');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Run the whole-history search and select its result, so the speed
    // dial has actions to offer. The label exists in the list header and
    // in the footer; either button starts the same search.
    await tester.tap(find.text('Search entire history').first);
    await tester.pumpAndSettle();
    expect(find.byType(DeepSearchResultsBanner), findsOneWidget);
    await tester.tap(find.text('fix the parser'));
    await tester.pumpAndSettle();

    // Expand the dial.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Cherry-pick'), findsOneWidget);

    // Rung 1: the dial collapses; search text and deep mode survive.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Cherry-pick'), findsNothing);
    expect(find.byType(DeepSearchResultsBanner), findsOneWidget);
    expect(find.widgetWithText(TextField, 'fix'), findsOneWidget);

    // Rung 2: the search clears — and with it the filter the deep results
    // answered, so the mode leaves too and the window view returns.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'fix'), findsNothing);
    expect(find.byType(DeepSearchResultsBanner), findsNothing);
    expect(find.text('fix something'), findsWidgets);

    // Rung 3: nothing is dismissible; Escape is dead.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DeepSearchResultsBanner), findsNothing);
    expect(find.text('fix something'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Escape leaves a deep search that has no search text, then is dead',
    (tester) async {
      final service = _HistoryGitService(
        ({limit, branch, filePath, startPoints = const <String>[]}) async =>
            const Success(<GitCommit>[]),
        onSearchLog: ({query, pickaxe = false}) async =>
            Success([commit('m1', subject: 'authored deep match')]),
      );
      await _pumpHistory(
        tester,
        service: service,
        firstPage: [
          _commit('c1', parents: ['c2']),
          _commit('c2'),
        ],
      );

      // An author-only filter (the advanced dialog's path) leaves the search
      // field empty, so the "leave the mode" rung is the innermost enabled
      // one.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryScreen)),
        listen: false,
      );
      const filter = HistorySearchFilter(author: 'a');
      container.read(historySearchFilterProvider.notifier).state = filter;
      await tester.pump();
      unawaited(container.read(historyDeepSearchProvider.notifier).run(filter));
      await tester.pumpAndSettle();
      expect(find.byType(DeepSearchResultsBanner), findsOneWidget);

      // Escape leaves the mode and restores the windowed view.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DeepSearchResultsBanner), findsNothing);
      expect(find.text('message for c1'), findsWidgets);

      // With no text and no mode, Escape is dead.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('message for c1'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
