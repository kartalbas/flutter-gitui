// The paging contract of the commit window: the cursor is the window's
// boundary-parent set, a page is one bounded walk from that set - never
// --skip, never from HEAD - the end of history is detected exactly, a failed
// page keeps the window, and a reload preserves the paged depth while a
// scope change resets it.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/history/models/commit_window.dart';
import 'package:flutter_gitui/features/history/models/history_search_filter.dart';
import 'package:flutter_gitui/features/history/providers/commit_selection_provider.dart';
import 'package:flutter_gitui/features/history/providers/history_search_provider.dart';

import 'support/scripted_git_service.dart';

void main() {
  group('boundaryParentsOf is the exact cursor', () {
    test('a linear window points at the one unloaded parent', () {
      final window = [
        commit('a', parents: ['b']),
        commit('b', parents: ['c']),
      ];
      expect(CommitWindow.boundaryParentsOf(window), ['c']);
    });

    test('a merge cut keeps every open lane, in first-reference order', () {
      // m merges side branch x; the cut ends above both x and b, so both
      // lanes are open and both must be walked - a last-hash cursor would
      // silently drop x and everything behind it.
      final window = [
        commit('m', parents: ['a', 'x']),
        commit('a', parents: ['b']),
      ];
      expect(CommitWindow.boundaryParentsOf(window), ['x', 'b']);
    });

    test('a fully loaded history has no boundary, so hasMore is exact', () {
      final window = [
        commit('a', parents: ['b']),
        commit('b'),
      ];
      expect(CommitWindow.boundaryParentsOf(window), isEmpty);
    });

    test('extended dedupes defensively and recomputes the cursor', () {
      final first = CommitWindow.fromFirstPage(
        commits: [
          commit('a', parents: ['b']),
        ],
        scopeKey: 'k',
        canExtend: true,
      );
      final grown = first.extended([
        commit('b', parents: ['c']),
        commit('a', parents: ['b']),
      ]);
      expect(hashesOf(grown.commits), ['a', 'b']);
      expect(grown.boundaryParents, ['c']);
    });
  });

  group('the window notifier pages by cursor', () {
    List<GitCommit> firstPage() => [
      commit('c1', parents: ['c2']),
      commit('c2', parents: ['c3']),
    ];
    List<GitCommit> secondPage() => [
      commit('c3', parents: ['c4']),
      commit('c4'),
    ];

    ProviderContainer harness(ScriptedGitService service) {
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith((ref) => service),
          defaultCommitLimitProvider.overrideWith((ref) => 2),
          commitHistoryProvider.overrideWith((ref) => firstPage()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('loadMore walks from the boundary with the page limit', () async {
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) async {
        return Success(
          startPoints.isEmpty ? const <GitCommit>[] : secondPage(),
        );
      });
      final container = harness(service);

      var window = await container.read(commitWindowProvider.future);
      expect(window.hasMore, isTrue);
      expect(window.boundaryParents, ['c3']);

      await container.read(commitWindowProvider.notifier).loadMore();

      window = await container.read(commitWindowProvider.future);
      expect(hashesOf(window.commits), ['c1', 'c2', 'c3', 'c4']);
      // The page continued from the cursor - never from HEAD, never skip.
      expect(service.lastStartPoints, ['c3']);
      expect(service.lastLimit, 2);
      expect(service.lastTopoOrder, isTrue);
      // The root is loaded: the cursor is empty and the end is exact.
      expect(window.hasMore, isFalse);
    });

    test('a failing page keeps the window and reports inline', () async {
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) async {
        return const Failure('fatal: boom');
      });
      final container = harness(service);

      await container.read(commitWindowProvider.future);
      await container.read(commitWindowProvider.notifier).loadMore();

      final window = await container.read(commitWindowProvider.future);
      expect(hashesOf(window.commits), ['c1', 'c2']);
      expect(window.loadMoreError, contains('boom'));
      expect(window.isLoadingMore, isFalse);
      expect(window.hasMore, isTrue);
    });

    test('a reload preserves the paged depth with one cursor walk', () async {
      var cursorCalls = 0;
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) async {
        cursorCalls++;
        expect(startPoints, ['c3']);
        expect(limit, 2);
        return Success(secondPage());
      });
      final container = harness(service);

      await container.read(commitWindowProvider.future);
      await container.read(commitWindowProvider.notifier).loadMore();
      expect(
        (await container.read(commitWindowProvider.future)).commits,
        hasLength(4),
      );

      // The app-wide refresh signal: every post-action refresh and the
      // app-bar Refresh invalidate exactly this provider.
      container.invalidate(commitHistoryProvider);

      final window = await container.read(commitWindowProvider.future);
      expect(hashesOf(window.commits), ['c1', 'c2', 'c3', 'c4']);
      // One page + one restore: the depth came back without --skip and
      // without snapping the list to a single page.
      expect(cursorCalls, 2);
    });

    test('a scope change resets the depth to one page', () async {
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) async {
        if (branch == 'feature') {
          return Success([
            commit('s1', parents: ['s2']),
          ]);
        }
        return Success(secondPage());
      });
      final container = harness(service);

      await container.read(commitWindowProvider.future);
      await container.read(commitWindowProvider.notifier).loadMore();
      expect(
        (await container.read(commitWindowProvider.future)).commits,
        hasLength(4),
      );

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(branch: 'feature');

      final window = await container.read(commitWindowProvider.future);
      expect(hashesOf(window.commits), ['s1']);
      // A branch scope is a plain reachability walk: it pages like unscoped.
      expect(window.canExtend, isTrue);
      expect(window.hasMore, isTrue);
    });

    test('a path scope cannot extend and a tag names one commit', () async {
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) async {
        return Success([
          commit('p1', parents: ['p2']),
        ]);
      });
      final container = harness(service);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(filePath: 'lib/main.dart');
      var window = await container.read(commitWindowProvider.future);
      expect(window.canExtend, isFalse);
      expect(window.hasMore, isFalse);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(tags: ['v1.0.0']);
      window = await container.read(commitWindowProvider.future);
      expect(window.canExtend, isFalse);
      expect(service.lastLimit, 1);
    });

    test('the selection survives a page append', () {
      // The #247 rule needs no new code for paging: appending rows cannot
      // remove a selected hash from the displayed list.
      final selection = CommitSelection.single('c2');
      expect(selection.resolve(firstPage()).primary?.hash, 'c2');
      expect(
        selection.resolve([...firstPage(), ...secondPage()]).primary?.hash,
        'c2',
      );
    });

    test('an abandoned page never resurfaces as state', () async {
      final gate = Completer<Result<List<GitCommit>>>();
      final service = ScriptedGitService(({
        limit,
        branch,
        filePath,
        startPoints = const <String>[],
      }) {
        if (startPoints.isNotEmpty) return gate.future;
        return Future.value(const Success(<GitCommit>[]));
      });
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith((ref) => service),
          defaultCommitLimitProvider.overrideWith((ref) => 2),
          commitHistoryProvider.overrideWith((ref) => firstPage()),
        ],
      );

      await container.read(commitWindowProvider.future);
      final pending = container.read(commitWindowProvider.notifier).loadMore();

      // The screen goes away / the repository switches: dispose cancels the
      // page's token, which is what kills the underlying process.
      container.dispose();
      expect(service.lastGetLogToken?.isCancelled, isTrue);

      gate.complete(Success(secondPage()));
      // Completes without throwing and without writing disposed state.
      await pending;
    });
  });
}
