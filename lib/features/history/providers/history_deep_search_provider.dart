import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/git/git_cancellation.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/history_search_filter.dart';
import 'history_search_provider.dart';

/// Phases of a whole-history search.
enum DeepSearchStatus { idle, running, results, failed }

/// What the history view needs to render deep-search mode.
///
/// Deep search is a mode over the *display*, never over the window: the
/// loaded window and the in-memory filter stay untouched underneath, so
/// leaving the mode restores exactly what the user had.
@immutable
class DeepSearchState {
  const DeepSearchState({
    required this.status,
    this.filter,
    this.pickaxe = false,
    this.results = const [],
    this.capped = false,
    this.error,
  });

  static const idle = DeepSearchState(status: DeepSearchStatus.idle);

  final DeepSearchStatus status;

  /// The filter the search ran with. Deep results answer this exact filter
  /// and no other; any change to the live filter resets the mode.
  final HistorySearchFilter? filter;

  /// Whether the run matched changed content (`-S`) instead of messages.
  final bool pickaxe;

  final List<GitCommit> results;

  /// True when the result list hit [AppConstants.deepSearchResultLimit], so
  /// the banner can say the list is a prefix, not the total.
  final bool capped;

  final String? error;

  bool get isActive => status != DeepSearchStatus.idle;
}

/// The single owner of whole-history search: starting it, cancelling it,
/// and guaranteeing an abandoned run stops costing anything.
class DeepSearchNotifier extends Notifier<DeepSearchState> {
  GitCancellationToken? _token;

  @override
  DeepSearchState build() {
    // Any change to the live filter invalidates deep results - they answered
    // one exact query - and a repository switch invalidates them doubly, so
    // both watches reset the mode to idle. The rebuild also runs onDispose,
    // which kills a search still in flight.
    ref.watch(historySearchFilterProvider);
    ref.watch(gitServiceProvider);
    ref.onDispose(_abandon);
    return DeepSearchState.idle;
  }

  void _abandon() {
    _token?.cancel();
    _token = null;
  }

  /// Runs one whole-history search with [filter] pushed down to git.
  ///
  /// [pickaxe] switches from message matching (`--grep`) to changed-content
  /// matching (`-S`) - the slower of the two deliberate operations.
  Future<void> run(HistorySearchFilter filter, {bool pickaxe = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    _abandon();
    final token = _token = GitCancellationToken();
    state = DeepSearchState(
      status: DeepSearchStatus.running,
      filter: filter,
      pickaxe: pickaxe,
    );

    final result = await gitService.searchLog(
      query: filter.query,
      author: filter.author,
      since: filter.fromDate?.toIso8601String(),
      until: filter.toDate?.toIso8601String(),
      useRegex: filter.useRegex,
      caseSensitive: filter.caseSensitive,
      pickaxe: pickaxe,
      limit: AppConstants.deepSearchResultLimit,
      cancellationToken: token,
    );

    // A cancelled search's outcome is the output of a killed process; it
    // must surface neither as results nor as an error.
    if (token.isCancelled || !ref.mounted) return;

    result.when(
      success: (commits) => state = DeepSearchState(
        status: DeepSearchStatus.results,
        filter: filter,
        pickaxe: pickaxe,
        results: commits,
        capped: commits.length >= AppConstants.deepSearchResultLimit,
      ),
      failure: (message, error, stackTrace) => state = DeepSearchState(
        status: DeepSearchStatus.failed,
        filter: filter,
        pickaxe: pickaxe,
        error: message,
      ),
    );
  }

  /// Cancels a running search and leaves deep mode.
  void clear() {
    _abandon();
    state = DeepSearchState.idle;
  }
}

/// Provider for the history view's whole-history search mode.
///
/// autoDispose is the cancellation guarantee for navigation: when the
/// history screen stops watching this, the element is disposed and the
/// running git process is killed.
final historyDeepSearchProvider =
    NotifierProvider.autoDispose<DeepSearchNotifier, DeepSearchState>(
      DeepSearchNotifier.new,
    );
