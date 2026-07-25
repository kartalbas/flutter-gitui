import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../git/git_service.dart';
import '../git/git_command_log_provider.dart';
import '../git/git_exception.dart';
import '../config/config_providers.dart';
import 'models/remote_check_failure.dart';
import 'models/repository_status.dart';
import 'models/workspace_repository.dart';
import 'workspace_provider.dart';
import '../services/logger_service.dart';
import '../services/progress_service.dart';

/// Provider for repository statuses (cached)
class RepositoryStatusNotifier
    extends StateNotifier<Map<String, RepositoryStatus>> {
  final Ref ref;

  RepositoryStatusNotifier(this.ref) : super({});

  /// Refresh status for a single repository.
  ///
  /// With [fetchRemote] the remote is contacted first, so the ahead/behind
  /// counts describe the current remote state rather than whatever was last
  /// known locally, and the result is stamped as verified. Without it the
  /// counts are only as fresh as the last fetch, which is why a repository that
  /// has never been fetched reports as unchecked instead of in sync.
  /// [allowPrompts] lets the credential helper open its sign-in window. Only
  /// for a check the user explicitly asked for: the background sweep must never
  /// interrupt them with a login dialog for work they did not start.
  Future<void> refreshStatus(
    WorkspaceRepository repository, {
    bool fetchRemote = false,
    bool allowPrompts = false,
  }) async {
    // Get git executable path from config
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final configLoading = ref.read(configLoadingProvider);

    Logger.debug(
      '[REFRESH] ${repository.displayName}: gitPath=${gitExecutablePath ?? "null"}, configLoading=$configLoading',
    );

    // GUARD: If git path not configured yet (config still loading), skip check
    // This prevents marking all repos as "Broken" during startup race condition
    if (gitExecutablePath == null || gitExecutablePath.isEmpty) {
      Logger.warning(
        '[REFRESH] Skipping ${repository.displayName} - git path not configured yet (configLoading=$configLoading)',
      );
      // While the config is still loading a path may still arrive, so keep the
      // loading state. Once loading has finished, an empty path is the final
      // answer and the card must say so instead of spinning forever.
      if (!configLoading) {
        state = {...state, repository.path: RepositoryStatus.gitNotConfigured};
      }
      return;
    }

    // Create a temporary GitService instance for this specific repository path
    // We don't use gitServiceProvider because it requires a repo to be "selected"
    // Wire up command logging so all git commands appear in the log
    final gitService = GitService(
      repository.path,
      gitExecutablePath: gitExecutablePath,
      onCommandExecuted: (log) {
        ref.read(gitCommandLogProvider.notifier).addLog(log);
      },
      // The background sweep must never open a login window for work the user
      // did not start; such a repository stays unverified and says so. Only an
      // explicitly requested sign-in lifts this.
      allowCredentialPrompts: allowPrompts,
    );

    // Only this repository spins, and only while its own check runs. Marking
    // every card up front, as refreshAll used to, spun the whole dashboard for
    // work happening on one repository and said nothing about which. The
    // existing data is kept so the card refreshes in place instead of blanking.
    final before = state[repository.path];
    state = {
      ...state,
      repository.path: (before ?? RepositoryStatus.unknown).copyWith(
        isLoading: true,
      ),
    };

    try {
      final stopwatch = Stopwatch()..start();
      Logger.debug('Checking ${repository.displayName}...');

      // Contacting the remote is what makes the ahead/behind counts describe
      // now instead of the last fetch. A failure here (offline, no auth) must
      // not fail the whole check: the local state is still worth showing, it
      // simply stays marked unverified.
      DateTime? remoteCheckedAt;
      var remoteCheckFailure = RemoteCheckFailure.none;
      if (fetchRemote) {
        final fetched = await gitService.fetch();
        fetched.when(
          success: (_) => remoteCheckedAt = DateTime.now(),
          failure: (message, error, stackTrace) {
            // Which failure it is decides what the card can offer: only a
            // missing sign-in is something the user can resolve, and saying so
            // is the difference between an actionable card and a silent one.
            remoteCheckFailure = classifyRemoteCheckFailure(
              error is GitException ? '$message\n${error.stderr}' : message,
            );
            Logger.debug(
              '[REFRESH] Fetch failed for ${repository.displayName}: '
              '$remoteCheckFailure',
            );
          },
        );
      } else {
        // Keep an earlier verification and its reason: a plain refresh must
        // neither downgrade a repository that was fetched a moment ago back to
        // unchecked, nor forget that it needs a sign-in.
        final previous = state[repository.path];
        remoteCheckedAt = previous?.remoteCheckedAt;
        remoteCheckFailure = previous?.remoteCheckFailure ?? remoteCheckFailure;
      }

      final statusMap = await gitService.getRepositoryStatus(repository.path);
      stopwatch.stop();

      Logger.debug(
        '${repository.displayName}: ${stopwatch.elapsedMilliseconds}ms',
      );

      // Log slow checks (over 2 seconds)
      if (stopwatch.elapsedMilliseconds > 2000) {
        Logger.warning(
          'Slow status check for ${repository.displayName}: ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      if (statusMap != null) {
        final status = RepositoryStatus(
          exists: statusMap['exists'] as bool? ?? false,
          isValidGit: statusMap['isValidGit'] as bool? ?? false,
          currentBranch: statusMap['currentBranch'] as String?,
          hasRemote: statusMap['hasRemote'] as bool? ?? false,
          commitsAhead: statusMap['commitsAhead'] as int? ?? 0,
          commitsBehind: statusMap['commitsBehind'] as int? ?? 0,
          hasUncommittedChanges:
              statusMap['hasUncommittedChanges'] as bool? ?? false,
          remoteCheckedAt: remoteCheckedAt,
          remoteCheckFailure: remoteCheckFailure,
          remoteUrl: statusMap['remoteUrl'] as String?,
        );

        state = {...state, repository.path: status};
      } else {
        // Nothing came back, so there is nothing to show - but the spinner
        // must still stop, or this card would keep turning forever.
        state = {
          ...state,
          repository.path: (before ?? RepositoryStatus.unknown).copyWith(
            isLoading: false,
          ),
        };
      }
    } catch (e) {
      Logger.error('Error checking ${repository.displayName}', e);
      // On error, mark as broken
      state = {...state, repository.path: RepositoryStatus.broken};
    }
  }

  /// Refresh statuses for all repositories.
  ///
  /// With [fetchRemote] every repository's remote is contacted first, which is
  /// what makes the cards report the current remote state instead of the last
  /// known one. That costs one network round trip per repository, so the local
  /// refresh that runs on startup and after local operations leaves it off and
  /// the background sweep turns it on.
  Future<void> refreshAll({bool fetchRemote = false}) async {
    final repositories = ref.read(workspaceProvider);
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final configLoading = ref.read(configLoadingProvider);

    Logger.info(
      '[REFRESH_ALL] Starting refresh of ${repositories.length} repositories (gitPath=${gitExecutablePath ?? "null"}, configLoading=$configLoading)',
    );

    // No blanket loading state: refreshStatus marks each repository while its
    // own check runs, so a card spins for its own work rather than because
    // something is happening somewhere in the workspace.

    // A named, non-blocking operation so the activity line can say what is
    // running and how far it got, without a barrier over work the user did not
    // start. Only worth announcing when the remote is contacted: a local pass
    // finishes well inside the show delay and would announce nothing.
    final progress = fetchRemote && repositories.isNotEmpty
        ? ref.read(progressProvider.notifier)
        : null;
    progress?.startOperation(
      'Checking repositories',
      repositories.length,
      isBlocking: false,
    );

    // Refresh all repositories in parallel
    // Each will update the UI as soon as it completes
    final stopwatch = Stopwatch()..start();
    try {
      await Future.wait(
        repositories.map(
          (repo) => refreshStatus(
            repo,
            fetchRemote: fetchRemote,
          ).whenComplete(() => progress?.incrementProgress()),
        ),
      );
    } finally {
      // The indicator must not outlive the sweep even if a check throws.
      progress?.completeOperation();
    }
    stopwatch.stop();
    Logger.info(
      'Analyzed ${repositories.length} repositories in ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  /// Drop the cached status of a repository that left the workspace, so the
  /// stale entry no longer feeds the workspace-wide counters below.
  void removeStatus(String path) {
    if (!state.containsKey(path)) {
      return;
    }
    final newState = Map<String, RepositoryStatus>.from(state);
    newState.remove(path);
    state = newState;
  }

  /// Get status for a specific repository path
  RepositoryStatus getStatus(String path) {
    return state[path] ?? RepositoryStatus.unknown;
  }

  /// Get count of repositories that need attention
  int get repositoriesNeedingAttention {
    return state.values.where((status) => status.needsAttention).length;
  }

  /// Get count of broken repositories
  int get brokenRepositories {
    return state.values.where((status) => status.isBroken).length;
  }

  /// Get count of repositories with incoming changes
  int get repositoriesWithIncoming {
    return state.values.where((status) => status.hasIncoming).length;
  }

  /// Get count of repositories with outgoing changes
  int get repositoriesWithOutgoing {
    return state.values.where((status) => status.hasOutgoing).length;
  }

  /// Get count of repositories with uncommitted changes
  int get repositoriesWithUncommitted {
    return state.values.where((status) => status.hasUncommittedChanges).length;
  }
}

/// Workspace repository status provider (for all repos in workspace)
final workspaceRepositoryStatusProvider =
    StateNotifierProvider<
      RepositoryStatusNotifier,
      Map<String, RepositoryStatus>
    >((ref) {
      final notifier = RepositoryStatusNotifier(ref);

      // Check if config is ALREADY loaded (provider created after config finished loading)
      final configLoading = ref.read(configLoadingProvider);
      Logger.debug(
        '[PROVIDER_INIT] workspaceRepositoryStatusProvider created, configLoading=$configLoading',
      );

      if (!configLoading) {
        // Config already loaded before this provider was created
        // Trigger refresh immediately (after microtask to ensure provider is fully initialized)
        Logger.info(
          '[PROVIDER_INIT] Config already loaded - scheduling immediate refresh',
        );
        Future.microtask(() => notifier.refreshAll());
      }

      // Listen to config loading state for future changes
      // This handles the case where provider is created BEFORE config finishes loading
      ref.listen(configLoadingProvider, (previous, next) {
        Logger.debug(
          '[LISTENER] Config loading state changed: previous=$previous, next=$next',
        );
        if (previous == true && next == false) {
          // Config just finished loading - refresh all repository statuses
          Logger.info(
            '[LISTENER] Config loaded - triggering repository status refresh',
          );
          Future.microtask(() => notifier.refreshAll());
        }
      });

      // Drop the cached status of any repository that leaves the workspace, so
      // its stale entry no longer feeds the workspace-wide counters. This used
      // to live in the per-repository watchers; it belongs with the status.
      ref.listen(workspaceProvider, (previous, next) {
        if (previous == null) return;
        final nextPaths = next.map((r) => r.path).toSet();
        for (final repo in previous) {
          if (!nextPaths.contains(repo.path)) {
            notifier.removeStatus(repo.path);
          }
        }
      });

      return notifier;
    });

/// Provider for a single repository's status
final repositoryStatusByPathProvider =
    Provider.family<RepositoryStatus, String>((ref, path) {
      final statuses = ref.watch(workspaceRepositoryStatusProvider);
      return statuses[path] ?? RepositoryStatus.unknown;
    });

/// Provider for count of repositories needing attention
final repositoriesNeedingAttentionCountProvider = Provider<int>((ref) {
  final statuses = ref.watch(workspaceRepositoryStatusProvider);
  return statuses.values.where((status) => status.needsAttention).length;
});
