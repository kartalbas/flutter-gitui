// Whole-history search is explicit, pushed down to git, and abandonable:
// nothing runs until asked, the query reaches git for git to evaluate, a
// superseded or cancelled run is stopped at its token (which is wired to the
// process kill), and a stopped run's late result never surfaces.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/history/models/history_search_filter.dart';
import 'package:flutter_gitui/features/history/providers/history_deep_search_provider.dart';
import 'package:flutter_gitui/features/history/providers/history_search_provider.dart';

import 'support/scripted_git_service.dart';

void main() {
  ProviderContainer harness(ScriptedGitService service) {
    return ProviderContainer(
      overrides: [gitServiceProvider.overrideWith((ref) => service)],
    );
  }

  test('nothing runs until explicitly asked', () async {
    var searches = 0;
    final service = ScriptedGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) async {
        searches++;
        return const Success(<GitCommit>[]);
      },
    );
    final container = harness(service);
    addTearDown(container.dispose);
    final sub = container.listen(historyDeepSearchProvider, (_, _) {});
    addTearDown(sub.close);

    // Typing a filter narrows the window in memory; it must not start a
    // whole-history walk on its own.
    container.read(historySearchFilterProvider.notifier).state =
        const HistorySearchFilter(query: 'fix');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(historyDeepSearchProvider).status,
      DeepSearchStatus.idle,
    );
    expect(searches, 0);
  });

  test('the query is pushed down to git and results surface', () async {
    final service = ScriptedGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) async =>
          Success([commit('m1', subject: 'fix parser')]),
    );
    final container = harness(service);
    addTearDown(container.dispose);
    final sub = container.listen(historyDeepSearchProvider, (_, _) {});
    addTearDown(sub.close);

    const filter = HistorySearchFilter(query: 'fix');
    container.read(historySearchFilterProvider.notifier).state = filter;
    await container.read(historyDeepSearchProvider.notifier).run(filter);

    final state = container.read(historyDeepSearchProvider);
    expect(state.status, DeepSearchStatus.results);
    expect(hashesOf(state.results), ['m1']);
    expect(state.capped, isFalse);
    // The match is evaluated by git, not in memory.
    expect(service.lastSearchQuery, 'fix');
    expect(service.lastSearchPickaxe, isFalse);
  });

  test('a superseded run cancels its predecessor at the token', () async {
    final firstGate = Completer<Result<List<GitCommit>>>();
    var calls = 0;
    final service = ScriptedGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) {
        calls++;
        if (calls == 1) return firstGate.future;
        return Future.value(Success([commit('fresh')]));
      },
    );
    final container = harness(service);
    addTearDown(container.dispose);
    final sub = container.listen(historyDeepSearchProvider, (_, _) {});
    addTearDown(sub.close);

    final notifier = container.read(historyDeepSearchProvider.notifier);
    final first = notifier.run(const HistorySearchFilter(query: 'one'));
    final firstToken = service.lastSearchToken;

    await notifier.run(const HistorySearchFilter(query: 'two'));
    expect(firstToken?.isCancelled, isTrue);

    firstGate.complete(Success([commit('stale')]));
    await first;

    // The second run's answer stands; the stale one never surfaced.
    expect(hashesOf(container.read(historyDeepSearchProvider).results), [
      'fresh',
    ]);
  });

  test('cancel stops the run and its late result never surfaces', () async {
    final gate = Completer<Result<List<GitCommit>>>();
    final service = ScriptedGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) => gate.future,
    );
    final container = harness(service);
    final sub = container.listen(historyDeepSearchProvider, (_, _) {});

    final notifier = container.read(historyDeepSearchProvider.notifier);
    final pending = notifier.run(const HistorySearchFilter(query: 'slow'));
    expect(
      container.read(historyDeepSearchProvider).status,
      DeepSearchStatus.running,
    );

    // The Cancel button: mode exits and the token - wired to the process
    // kill in GitService - is cancelled.
    notifier.clear();
    expect(service.lastSearchToken?.isCancelled, isTrue);
    expect(
      container.read(historyDeepSearchProvider).status,
      DeepSearchStatus.idle,
    );

    gate.complete(Success([commit('late')]));
    await pending;
    expect(
      container.read(historyDeepSearchProvider).status,
      DeepSearchStatus.idle,
    );

    sub.close();
    container.dispose();
  });

  test('disposal cancels a running search', () async {
    final gate = Completer<Result<List<GitCommit>>>();
    final service = ScriptedGitService(
      ({limit, branch, filePath, startPoints = const <String>[]}) async =>
          const Success(<GitCommit>[]),
      onSearchLog: ({query, pickaxe = false}) => gate.future,
    );
    final container = harness(service);
    final sub = container.listen(historyDeepSearchProvider, (_, _) {});

    final pending = container
        .read(historyDeepSearchProvider.notifier)
        .run(const HistorySearchFilter(query: 'slow'));

    // Leaving the screen: the autoDispose element goes away and the token
    // cancels, which is what kills the git process.
    sub.close();
    container.dispose();
    expect(service.lastSearchToken?.isCancelled, isTrue);

    gate.complete(const Success(<GitCommit>[]));
    await pending;
  });

  test(
    'changing the live filter exits deep mode and cancels the run',
    () async {
      final gate = Completer<Result<List<GitCommit>>>();
      final service = ScriptedGitService(
        ({limit, branch, filePath, startPoints = const <String>[]}) async =>
            const Success(<GitCommit>[]),
        onSearchLog: ({query, pickaxe = false}) => gate.future,
      );
      final container = harness(service);
      addTearDown(container.dispose);
      final sub = container.listen(historyDeepSearchProvider, (_, _) {});
      addTearDown(sub.close);

      const filter = HistorySearchFilter(query: 'fix');
      container.read(historySearchFilterProvider.notifier).state = filter;
      final pending = container
          .read(historyDeepSearchProvider.notifier)
          .run(filter);
      expect(
        container.read(historyDeepSearchProvider).status,
        DeepSearchStatus.running,
      );

      // Typing: deep results answered the old query, so the mode resets and
      // the run is abandoned.
      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(query: 'fixed');

      expect(
        container.read(historyDeepSearchProvider).status,
        DeepSearchStatus.idle,
      );
      expect(service.lastSearchToken?.isCancelled, isTrue);

      gate.complete(const Success(<GitCommit>[]));
      await pending;
      expect(
        container.read(historyDeepSearchProvider).status,
        DeepSearchStatus.idle,
      );
    },
  );
}
