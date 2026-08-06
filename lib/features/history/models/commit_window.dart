import 'package:flutter/foundation.dart';

import '../../../core/git/models/commit.dart';
import 'history_search_filter.dart';

/// The loaded stretch of history plus everything needed to extend it.
///
/// [boundaryParents] is the paging cursor: every parent hash the window
/// references without containing. Continuing `git log` from exactly these
/// start points yields precisely the unloaded remainder of the history - see
/// [boundaryParentsOf] for why - so a page costs one bounded walk from the
/// window's edge, where `--skip=N` would re-walk N commits from HEAD first.
@immutable
class CommitWindow {
  const CommitWindow({
    required this.commits,
    required this.boundaryParents,
    required this.scopeKey,
    required this.canExtend,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// A window freshly loaded from git, with its cursor derived from it.
  factory CommitWindow.fromFirstPage({
    required List<GitCommit> commits,
    required String scopeKey,
    required bool canExtend,
  }) {
    return CommitWindow(
      commits: List.unmodifiable(commits),
      boundaryParents: boundaryParentsOf(commits),
      scopeKey: scopeKey,
      canExtend: canExtend,
    );
  }

  /// Loaded commits, children above parents (git's `--topo-order`).
  final List<GitCommit> commits;

  /// Parent hashes referenced by the window but not loaded into it: the open
  /// lanes at the window's bottom edge. Empty exactly when the entire
  /// reachable history is loaded.
  final List<String> boundaryParents;

  /// Identity of what the window is a window *of* - repository plus the
  /// git-scoped filter parts. A rebuild with the same key is a reload of the
  /// same window, so its paged depth is preserved; a different key is a
  /// different window and starts at one page. In-memory filter parts are
  /// deliberately absent: they never reshape the window, so they must not
  /// reset its depth either.
  final String scopeKey;

  /// Whether paging is defined for this window. False for a tag window (one
  /// commit by construction) and for a path-scoped window, whose history
  /// simplification makes a parent-hash cursor ambiguous.
  final bool canExtend;

  /// True while a page is being appended; drives the footer's progress face.
  final bool isLoadingMore;

  /// The failure of the last page load, shown inline in the footer with a
  /// retry, so a transient error never blanks the already-loaded window.
  final String? loadMoreError;

  /// Whether older history exists that is not loaded.
  bool get hasMore => canExtend && boundaryParents.isNotEmpty;

  /// The window with [page] appended and the cursor recomputed.
  ///
  /// Appending preserves the lane pass's invariant: the page is reachable
  /// only from the boundary parents, so every cross-boundary parent link
  /// points from an already-loaded child down into the page, never upward -
  /// the concatenation is again a valid children-above-parents order. The
  /// dedupe is defensive; by construction the page cannot overlap.
  CommitWindow extended(List<GitCommit> page) {
    final known = <String>{for (final commit in commits) commit.hash};
    final appended = [...commits];
    for (final commit in page) {
      if (known.add(commit.hash)) appended.add(commit);
    }
    return CommitWindow(
      commits: List.unmodifiable(appended),
      boundaryParents: boundaryParentsOf(appended),
      scopeKey: scopeKey,
      canExtend: canExtend,
    );
  }

  CommitWindow copyWith({bool? isLoadingMore, Object? loadMoreError = _unset}) {
    return CommitWindow(
      commits: commits,
      boundaryParents: boundaryParents,
      scopeKey: scopeKey,
      canExtend: canExtend,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: identical(loadMoreError, _unset)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }

  static const Object _unset = Object();

  /// Every parent hash referenced by [commits] but not contained in it, in
  /// first-reference order.
  ///
  /// Why this is the exact cursor: in a topological order every commit
  /// precedes its parents, so the unloaded remainder R is closed under
  /// "parent of". Any commit in R has a loaded descendant whose direct
  /// parent inside R is by definition in this boundary set B, hence R is
  /// reachable from B; conversely nothing loaded is reachable from B, or it
  /// would lie in R by the same closure. R equals reachability from B, which
  /// is exactly the set `git log <B>` walks - no duplicates, no misses,
  /// across any merge topology. A last-hash cursor has no such property: a
  /// topological cut can leave several lanes open, and only this set names
  /// them all.
  static List<String> boundaryParentsOf(List<GitCommit> commits) {
    final loaded = <String>{for (final commit in commits) commit.hash};
    final seen = <String>{};
    final boundary = <String>[];
    for (final commit in commits) {
      for (final parent in commit.parents) {
        if (!loaded.contains(parent) && seen.add(parent)) {
          boundary.add(parent);
        }
      }
    }
    return boundary;
  }

  /// One string identifying the (repository, git-scope) pair this window
  /// belongs to.
  static String scopeKeyFor({
    required String? repoPath,
    required HistorySearchFilter filter,
  }) {
    final tags = filter.tags;
    final tag = (tags != null && tags.isNotEmpty) ? tags.first : '';
    return [
      repoPath ?? '',
      filter.filePath ?? '',
      filter.branch ?? '',
      tag,
    ].join('\u0000');
  }
}
