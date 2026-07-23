// Two invariants of the history view's data flow: filtering is a pure
// function over the window of commits already in memory, and a git failure
// surfaces as an error instead of masquerading as an empty result. The first
// keeps a keystroke in the search field from spawning a git process; the
// second keeps "no results, clear your filters" from rendering while git
// itself is broken.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/history/models/history_search_filter.dart';
import 'package:flutter_gitui/features/history/providers/history_search_provider.dart';
import 'package:flutter_gitui/features/history/services/history_search_service.dart';

GitCommit commit(
  String hash, {
  String subject = 's',
  String author = 'a',
  DateTime? date,
}) {
  final when = date ?? DateTime.utc(2026);
  return GitCommit(
    hash: hash,
    shortHash: hash,
    author: author,
    authorEmail: '$author@example.com',
    authorDate: when,
    committer: author,
    committerEmail: '$author@example.com',
    committerDate: when,
    subject: subject,
    body: '',
    parents: const [],
    refs: const [],
  );
}

typedef ScriptedGetLog =
    Future<Result<List<GitCommit>>> Function({
      int? limit,
      String? branch,
      String? filePath,
    });

/// A [GitService] whose getLog is scripted, so no test ever shells out.
class ScriptedGitService extends GitService {
  ScriptedGitService(this.onGetLog) : super('.');

  final ScriptedGetLog onGetLog;

  /// Recorded rather than scripted: the ordering flag matters to the lane
  /// renderer, not to which commits a scripted answer returns.
  bool? lastTopoOrder;

  @override
  Future<Result<List<GitCommit>>> getLog({
    int? limit,
    String? branch,
    String? filePath,
    String? grepMessage,
    String? author,
    String? since,
    String? until,
    bool allMatch = false,
    bool topoOrder = false,
  }) {
    lastTopoOrder = topoOrder;
    return onGetLog(limit: limit, branch: branch, filePath: filePath);
  }
}

List<String> hashesOf(List<GitCommit> commits) => [
  for (final c in commits) c.hash,
];

void main() {
  group('filtering is a pure function over the window', () {
    final service = HistorySearchService();

    final window = [
      commit(
        'aaa',
        subject: 'fix log parser',
        author: 'alice',
        date: DateTime.utc(2026, 3, 10),
      ),
      commit(
        'bbb',
        subject: 'add readme',
        author: 'bob',
        date: DateTime.utc(2026, 2, 5),
      ),
      commit(
        'ccc',
        subject: 'fix flaky test',
        author: 'alice',
        date: DateTime.utc(2026, 1, 20),
      ),
    ];

    test('a text query narrows by message, author and hash', () {
      final byText = service.filterCommits(
        window,
        const HistorySearchFilter(query: 'fix', fuzzyMatch: false),
      );
      expect(hashesOf(byText), ['aaa', 'ccc']);

      final byHash = service.filterCommits(
        window,
        const HistorySearchFilter(query: 'bbb', fuzzyMatch: false),
      );
      expect(hashesOf(byHash), ['bbb']);
    });

    test('an author filter narrows to that author', () {
      final result = service.filterCommits(
        window,
        const HistorySearchFilter(author: 'bob', fuzzyMatch: false),
      );

      expect(hashesOf(result), ['bbb']);
    });

    test('a date range is applied in memory, not by git', () {
      final result = service.filterCommits(
        window,
        HistorySearchFilter(
          fromDate: DateTime.utc(2026, 2),
          toDate: DateTime.utc(2026, 2, 28),
        ),
      );

      expect(hashesOf(result), ['bbb']);
    });

    test('a hash prefix filter matches case-insensitively', () {
      final result = service.filterCommits(
        window,
        const HistorySearchFilter(hashPrefixes: ['CC']),
      );

      expect(hashesOf(result), ['ccc']);
    });

    test('the window itself is never reordered or mutated', () {
      final before = hashesOf(window);

      service.filterCommits(
        window,
        const HistorySearchFilter(query: 'fix', fuzzyMatch: false),
      );

      expect(hashesOf(window), before);
    });
  });

  group('the window is the only git boundary', () {
    test('typing a text filter never invokes git', () async {
      var gitCalls = 0;
      final window = [
        commit('aaa', subject: 'fix parser'),
        commit('bbb', subject: 'add docs'),
      ];
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith(
            (ref) => ScriptedGitService(({limit, branch, filePath}) async {
              gitCalls++;
              return const Success(<GitCommit>[]);
            }),
          ),
          defaultCommitLimitProvider.overrideWith((ref) => 42),
          commitHistoryProvider.overrideWith((ref) => window),
        ],
      );
      addTearDown(container.dispose);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(query: 'parser', fuzzyMatch: false);
      expect(await container.read(filteredCommitsProvider.future), [
        window.first,
      ]);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(query: 'docs', fuzzyMatch: false);
      expect(await container.read(filteredCommitsProvider.future), [
        window.last,
      ]);

      expect(gitCalls, 0);
    });

    test(
      'a file-path filter reloads the window with the browsing limit',
      () async {
        int? seenLimit;
        String? seenBranch;
        String? seenFilePath;
        final scoped = [commit('ccc', subject: 'touches the file')];
        final container = ProviderContainer(
          overrides: [
            gitServiceProvider.overrideWith(
              (ref) => ScriptedGitService(({limit, branch, filePath}) async {
                seenLimit = limit;
                seenBranch = branch;
                seenFilePath = filePath;
                return Success(scoped);
              }),
            ),
            defaultCommitLimitProvider.overrideWith((ref) => 42),
            commitHistoryProvider.overrideWith((ref) => [commit('aaa')]),
          ],
        );
        addTearDown(container.dispose);

        container.read(historySearchFilterProvider.notifier).state =
            const HistorySearchFilter(filePath: 'lib/main.dart');

        expect(await container.read(filteredCommitsProvider.future), scoped);
        // The same configured limit as browsing: a search must never quietly
        // cover a different stretch of history than the list it filters.
        expect(seenLimit, 42);
        expect(seenFilePath, 'lib/main.dart');
        expect(seenBranch, isNull);
      },
    );

    test('a tag filter loads exactly the tagged commit', () async {
      int? seenLimit;
      String? seenBranch;
      final tagged = [commit('ddd', subject: 'release')];
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith(
            (ref) => ScriptedGitService(({limit, branch, filePath}) async {
              seenLimit = limit;
              seenBranch = branch;
              return Success(tagged);
            }),
          ),
          defaultCommitLimitProvider.overrideWith((ref) => 42),
          commitHistoryProvider.overrideWith((ref) => [commit('aaa')]),
        ],
      );
      addTearDown(container.dispose);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(tags: ['v1.0.0']);

      expect(await container.read(filteredCommitsProvider.future), tagged);
      expect(seenBranch, 'v1.0.0');
      expect(seenLimit, 1);
    });

    test('the scoped window is loaded in topological order', () async {
      final service = ScriptedGitService(
        ({limit, branch, filePath}) async => Success([commit('ccc')]),
      );
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith((ref) => service),
          defaultCommitLimitProvider.overrideWith((ref) => 42),
          commitHistoryProvider.overrideWith((ref) => [commit('aaa')]),
        ],
      );
      addTearDown(container.dispose);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(filePath: 'lib/main.dart');
      await container.read(filteredCommitsProvider.future);

      // The lane pass assumes children sort above parents; a scoped window
      // loaded in date order would hand it rows the lanes cannot explain.
      expect(service.lastTopoOrder, isTrue);
    });

    test(
      'a failing history load surfaces as an error, not an empty result',
      () async {
        final container = ProviderContainer(
          // Without this the automatic retry keeps the future pending, which
          // would hang the expectLater below instead of surfacing the error.
          retry: (retryCount, error) => null,
          overrides: [
            gitServiceProvider.overrideWith((ref) => null),
            commitHistoryProvider.overrideWith(
              (ref) => throw Exception('fatal: not a git repository'),
            ),
          ],
        );
        addTearDown(container.dispose);

        // With a text filter active this used to be swallowed into an empty
        // list, rendering as "no results" while every git call was failing.
        container.read(historySearchFilterProvider.notifier).state =
            const HistorySearchFilter(query: 'parser', fuzzyMatch: false);

        await expectLater(
          container.read(filteredCommitsProvider.future),
          throwsException,
        );
      },
    );

    test(
      'a failing scoped window surfaces as an error, not an empty result',
      () async {
        final container = ProviderContainer(
          // Without this the automatic retry keeps the future pending, which
          // would hang the expectLater below instead of surfacing the error.
          retry: (retryCount, error) => null,
          overrides: [
            gitServiceProvider.overrideWith(
              (ref) => ScriptedGitService(
                ({limit, branch, filePath}) async =>
                    const Failure('fatal: bad revision'),
              ),
            ),
            defaultCommitLimitProvider.overrideWith((ref) => 42),
            commitHistoryProvider.overrideWith((ref) => [commit('aaa')]),
          ],
        );
        addTearDown(container.dispose);

        container.read(historySearchFilterProvider.notifier).state =
            const HistorySearchFilter(filePath: 'lib/main.dart');

        await expectLater(
          container.read(filteredCommitsProvider.future),
          throwsException,
        );
      },
    );

    test('refreshing the history reaches the filtered view', () async {
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          gitServiceProvider.overrideWith((ref) => null),
          commitHistoryProvider.overrideWith((ref) {
            loads++;
            return loads == 1
                ? [commit('aaa', subject: 'fix parser')]
                : [
                    commit('bbb', subject: 'fix parser again'),
                    commit('aaa', subject: 'fix parser'),
                  ];
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(historySearchFilterProvider.notifier).state =
          const HistorySearchFilter(query: 'parser', fuzzyMatch: false);

      expect(hashesOf(await container.read(filteredCommitsProvider.future)), [
        'aaa',
      ]);

      // Every post-action refresh invalidates commitHistoryProvider; while a
      // filter was active this used to be a silent no-op.
      container.invalidate(commitHistoryProvider);

      expect(hashesOf(await container.read(filteredCommitsProvider.future)), [
        'bbb',
        'aaa',
      ]);
    });
  });
}
