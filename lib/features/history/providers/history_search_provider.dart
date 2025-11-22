import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/history_search_filter.dart';
import '../services/history_search_service.dart';

/// Provider for search service
final historySearchServiceProvider = Provider((ref) => HistorySearchService());

/// Provider for current search filter
final historySearchFilterProvider =
    StateProvider<HistorySearchFilter>((ref) => const HistorySearchFilter.empty());

/// Provider for filtered commits based on search criteria
/// Now searches across ALL commits using git log, not just loaded ones
final filteredCommitsProvider = FutureProvider<List<GitCommit>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  final filter = ref.watch(historySearchFilterProvider);

  if (gitService == null) return [];

  // If no search filter, return default history
  if (filter.isEmpty) {
    final commitsAsync = ref.watch(commitHistoryProvider);
    return commitsAsync.when(
      data: (commits) => commits,
      loading: () => [],
      error: (_, _) => [],
    );
  }

  // Use git log with search parameters to search ALL commits
  try {
    // If searching by tags, use tag with -n 1 to get only the commit the tag points to
    String? branchOrTag = filter.branch;
    int? limitOverride;

    if (filter.tags != null && filter.tags!.isNotEmpty) {
      // Use the first tag for filtering
      branchOrTag = filter.tags!.first;
      // Override limit to 1 to get only the commit the tag points to
      limitOverride = 1;
    }

    return await gitService.getLog(
      grepMessage: filter.query,
      author: filter.author,
      since: filter.fromDate?.toIso8601String(),
      until: filter.toDate?.toIso8601String(),
      filePath: filter.filePath,
      branch: branchOrTag,
      limit: limitOverride ?? 1000, // Use 1 for tags, 1000 for regular search
    );
  } catch (e) {
    return [];
  }
});

/// Provider for search results with relevance scores
final searchResultsProvider = Provider<List<SearchResult>?>((ref) {
  final commitsAsync = ref.watch(commitHistoryProvider);
  final filter = ref.watch(historySearchFilterProvider);
  final searchService = ref.watch(historySearchServiceProvider);

  if (filter.query == null || filter.query!.isEmpty) {
    return null;
  }

  return commitsAsync.when(
    data: (commits) => searchService.searchCommits(
      commits,
      filter.query!,
      caseSensitive: filter.caseSensitive,
      useRegex: filter.useRegex,
      fuzzyMatch: filter.fuzzyMatch,
    ),
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provider for search history (recent searches)
final searchHistoryProvider = StateProvider<List<String>>((ref) => []);

/// Provider to add a search to history
final addSearchToHistoryProvider = Provider((ref) {
  return (String query) {
    if (query.trim().isEmpty) return;

    final history = ref.read(searchHistoryProvider);
    final updatedHistory = [
      query,
      ...history.where((q) => q != query),
    ].take(20).toList(); // Keep last 20 searches

    ref.read(searchHistoryProvider.notifier).state = updatedHistory;
  };
});
