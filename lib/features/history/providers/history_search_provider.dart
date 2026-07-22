import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
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
  );

  // Throwing keeps the failure visible: swallowed into an empty list, it
  // rendered as "no results, clear your filters" while git itself was broken.
  return result.unwrap();
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
