import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/git/git_cancellation.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/commit_graph.dart';
import '../models/commit_window.dart';
import '../models/history_search_filter.dart';
import '../services/history_search_service.dart';

/// Provider for search service
final historySearchServiceProvider = Provider((ref) => HistorySearchService());

/// Provider for current search filter
final historySearchFilterProvider = StateProvider<HistorySearchFilter>(
  (ref) => const HistorySearchFilter.empty(),
);

/// The single owner of the loaded commit window.
///
/// Loading, extending or reshaping the window is the only step that may
/// invoke git; everything else in the view is a pure function over it. Only
/// the filter parts git alone can answer reshape it - which commits touched
/// a file, are reachable from a branch, or carry a tag - and they use the
/// same configured limit as browsing, so a search can never quietly cover a
/// different stretch of history than the list it filters.
///
/// Paging continues from the window's boundary parents instead of an offset
/// (see [CommitWindow.boundaryParentsOf]), so a page costs one bounded walk
/// however deep the window already is. A rebuild with an unchanged scope -
/// the app-wide refresh signal, ref: invalidating [commitHistoryProvider] -
/// restores the previously paged depth, so a refresh after ten pages does
/// not snap the list back to one.
class CommitWindowNotifier extends AsyncNotifier<CommitWindow> {
  @override
  Future<CommitWindow> build() async {
    final filter = ref.watch(historySearchFilterProvider);
    final pageSize = ref.watch(defaultCommitLimitProvider);
    final gitService = ref.watch(gitServiceProvider);
    final scopeKey = CommitWindow.scopeKeyFor(
      repoPath: gitService?.repoPath,
      filter: filter,
    );

    // A superseded build - filter change, repository switch, refresh - kills
    // its in-flight restore walk instead of letting a dead process run on.
    final token = GitCancellationToken();
    ref.onDispose(token.cancel);

    // The depth the user had paged to. Read before the first await: during a
    // rebuild the state still carries the previous window. Same scope means
    // the depth is preserved; a different scope is a different window and
    // starts at one page again.
    final previous = state.value;
    final previousDepth = (previous != null && previous.scopeKey == scopeKey)
        ? previous.commits.length
        : 0;

    // Awaited even when a git-scoped filter replaces it: invalidating
    // commitHistoryProvider is the app-wide refresh signal, and depending on
    // it here is what makes Refresh work while a filter is active.
    final history = await ref.watch(commitHistoryProvider.future);

    CommitWindow window;
    if (!filter.needsGitWindow) {
      window = CommitWindow.fromFirstPage(
        commits: history,
        scopeKey: scopeKey,
        canExtend: true,
      );
    } else {
      if (gitService == null) {
        return CommitWindow.fromFirstPage(
          commits: const [],
          scopeKey: scopeKey,
          canExtend: false,
        );
      }

      // A tag names exactly one commit, so the window is that commit alone.
      final tags = filter.tags;
      final tag = (tags != null && tags.isNotEmpty) ? tags.first : null;

      final result = await gitService.getLog(
        filePath: filter.filePath,
        branch: tag ?? filter.branch,
        limit: tag != null ? 1 : pageSize,
        // The same ordering as the unscoped window: the graph pass assumes
        // children sort above parents in whatever window it is handed.
        topoOrder: true,
        cancellationToken: token,
      );

      // Throwing keeps the failure visible: swallowed into an empty list, it
      // rendered as "no results, clear your filters" while git was broken.
      final commits = result.unwrap();

      // A tag window is one commit by construction; a path-scoped log is
      // history-simplified, so a parent-hash cursor is ambiguous for it. A
      // branch-scoped window is a plain reachability walk and pages exactly
      // like the unscoped one.
      final canExtend =
          tag == null && (filter.filePath == null || filter.filePath!.isEmpty);
      window = CommitWindow.fromFirstPage(
        commits: commits,
        scopeKey: scopeKey,
        canExtend: canExtend,
      );
    }

    // Depth-preserving reload: cursor walks fill the window back to where
    // the user had paged to - one call in practice - instead of --skip
    // re-walking the whole depth from HEAD.
    while (window.commits.length < previousDepth && window.hasMore) {
      final service = ref.read(gitServiceProvider);
      if (service == null) break;
      final result = await service.getLog(
        limit: previousDepth - window.commits.length,
        topoOrder: true,
        startPoints: window.boundaryParents,
        cancellationToken: token,
      );
      final grown = window.extended(result.unwrap());
      // A non-advancing walk must terminate the loop, not spin it.
      if (grown.commits.length == window.commits.length) break;
      window = grown;
    }

    return window;
  }

  /// Appends one page of older history to the window.
  ///
  /// Reentrancy-guarded - the footer can request one page at a time - and a
  /// failure lands in [CommitWindow.loadMoreError] with the window intact,
  /// so a transient error costs a retry, not the loaded history.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;
    final pageSize = ref.read(defaultCommitLimitProvider);

    // Dies with the current window: a rebuild (filter change, repository
    // switch, refresh) or the screen going away kills the page's process.
    final token = GitCancellationToken();
    ref.onDispose(token.cancel);

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: null),
    );

    final result = await gitService.getLog(
      limit: pageSize,
      topoOrder: true,
      startPoints: current.boundaryParents,
      cancellationToken: token,
    );

    // An abandoned page must not resurface as state: the window it belongs
    // to is already gone.
    if (token.isCancelled || !ref.mounted) return;

    result.when(
      success: (page) => state = AsyncData(current.extended(page)),
      failure: (message, error, stackTrace) => state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: message),
      ),
    );
  }
}

/// The window of commits loaded from git for the history view.
final commitWindowProvider =
    AsyncNotifierProvider<CommitWindowNotifier, CommitWindow>(
      CommitWindowNotifier.new,
    );

/// The lane layout of the loaded window, recomputed only when the window is.
///
/// Living next to the window is what keeps the pass out of the rows: each
/// list item merely looks its lanes up, so scrolling, selection changes and
/// repaints never walk the parent links again. A page append recomputes the
/// pass over the whole window, which turns the old boundary stubs into real
/// lanes.
final commitGraphProvider = FutureProvider<CommitGraph>((ref) async {
  final window = await ref.watch(commitWindowProvider.future);
  return CommitGraph.fromCommits(window.commits);
});

/// The commits the history view displays: the loaded window narrowed by the
/// in-memory criteria - text, fuzzy, regex, hash prefix, author, date.
///
/// This is a pure function over [commitWindowProvider], so a keystroke in the
/// search field recomputes a list match instead of spawning a git process.
final filteredCommitsProvider = FutureProvider<List<GitCommit>>((ref) async {
  final filter = ref.watch(historySearchFilterProvider);
  final searchService = ref.watch(historySearchServiceProvider);

  final window = await ref.watch(commitWindowProvider.future);
  return searchService.filterCommits(window.commits, filter);
});
