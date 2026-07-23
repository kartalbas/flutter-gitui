import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/commit_graph.dart';
import '../models/history_search_filter.dart';
import '../services/history_search_service.dart';

/// Provider for search service
final historySearchServiceProvider = Provider((ref) => HistorySearchService());

/// Provider for current search filter
final historySearchFilterProvider = StateProvider<HistorySearchFilter>(
  (ref) => const HistorySearchFilter.empty(),
);

/// The window of commits loaded from git for the history view.
///
/// Loading or reshaping this window is the only step that may invoke git.
/// Only the filter parts git alone can answer reshape it - which commits
/// touched a file, are reachable from a branch, or carry a tag - and they use
/// the same configured limit as browsing, so a search can never quietly cover
/// a different stretch of history than the list it filters.
final commitWindowProvider = FutureProvider<List<GitCommit>>((ref) async {
  final filter = ref.watch(historySearchFilterProvider);

  // Awaited even when a git-scoped filter replaces it: invalidating
  // commitHistoryProvider is the app-wide refresh signal, and depending on it
  // here is what makes Refresh work while a filter is active.
  final history = await ref.watch(commitHistoryProvider.future);
  if (!filter.needsGitWindow) return history;

  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return const [];

  // A tag names exactly one commit, so the window is that commit alone.
  final tags = filter.tags;
  final tag = (tags != null && tags.isNotEmpty) ? tags.first : null;

  final result = await gitService.getLog(
    filePath: filter.filePath,
    branch: tag ?? filter.branch,
    limit: tag != null ? 1 : ref.watch(defaultCommitLimitProvider),
    // The same ordering as the unscoped window: the graph pass assumes
    // children sort above parents in whatever window it is handed.
    topoOrder: true,
  );

  // Throwing keeps the failure visible: swallowed into an empty list, it
  // rendered as "no results, clear your filters" while git itself was broken.
  return result.unwrap();
});

/// The lane layout of the loaded window, recomputed only when the window is.
///
/// Living next to the window is what keeps the pass out of the rows: each
/// list item merely looks its lanes up, so scrolling, selection changes and
/// repaints never walk the parent links again.
final commitGraphProvider = FutureProvider<CommitGraph>((ref) async {
  final window = await ref.watch(commitWindowProvider.future);
  return CommitGraph.fromCommits(window);
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
  return searchService.filterCommits(window, filter);
});
