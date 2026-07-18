import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../git/git_service.dart';
import '../git/git_command_log_provider.dart';
import '../config/config_providers.dart';
import 'models/repository_status.dart';
import 'models/workspace_repository.dart';
import 'workspace_provider.dart';
import '../services/logger_service.dart';

/// Provider for repository statuses (cached)
class RepositoryStatusNotifier extends StateNotifier<Map<String, RepositoryStatus>> {
  final Ref ref;

  RepositoryStatusNotifier(this.ref) : super({});

  /// Refresh status for a single repository
  Future<void> refreshStatus(WorkspaceRepository repository) async {
    // Get git executable path from config
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final configLoading = ref.read(configLoadingProvider);

    Logger.debug('[REFRESH] ${repository.displayName}: gitPath=${gitExecutablePath ?? "null"}, configLoading=$configLoading');

    // GUARD: If git path not configured yet (config still loading), skip check
    // This prevents marking all repos as "Broken" during startup race condition
    if (gitExecutablePath == null || gitExecutablePath.isEmpty) {
      Logger.warning('[REFRESH] Skipping ${repository.displayName} - git path not configured yet (configLoading=$configLoading)');
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
    );

    try {
      final stopwatch = Stopwatch()..start();
      Logger.debug('Checking ${repository.displayName}...');
      final statusMap = await gitService.getRepositoryStatus(repository.path);
      stopwatch.stop();

      Logger.debug('${repository.displayName}: ${stopwatch.elapsedMilliseconds}ms');

      // Log slow checks (over 2 seconds)
      if (stopwatch.elapsedMilliseconds > 2000) {
        Logger.warning('Slow status check for ${repository.displayName}: ${stopwatch.elapsedMilliseconds}ms');
      }

      if (statusMap != null) {
        final status = RepositoryStatus(
          exists: statusMap['exists'] as bool? ?? false,
          isValidGit: statusMap['isValidGit'] as bool? ?? false,
          currentBranch: statusMap['currentBranch'] as String?,
          hasRemote: statusMap['hasRemote'] as bool? ?? false,
          commitsAhead: statusMap['commitsAhead'] as int? ?? 0,
          commitsBehind: statusMap['commitsBehind'] as int? ?? 0,
          hasUncommittedChanges: statusMap['hasUncommittedChanges'] as bool? ?? false,
        );

        state = {...state, repository.path: status};
      }
    } catch (e) {
      Logger.error('Error checking ${repository.displayName}', e);
      // On error, mark as broken
      state = {...state, repository.path: RepositoryStatus.broken};
    }
  }

  /// Refresh statuses for all repositories
  Future<void> refreshAll() async {
    final repositories = ref.read(workspaceProvider);
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final configLoading = ref.read(configLoadingProvider);

    Logger.info('[REFRESH_ALL] Starting refresh of ${repositories.length} repositories (gitPath=${gitExecutablePath ?? "null"}, configLoading=$configLoading)');

    // First, set all repositories to loading state immediately
    final loadingStates = <String, RepositoryStatus>{};
    for (final repo in repositories) {
      loadingStates[repo.path] = RepositoryStatus.unknown;
    }

    // Update state to show "Analyzing..." in UI
    state = {...state, ...loadingStates};
    Logger.debug('Set ${repositories.length} repositories to analyzing state');

    // Then refresh all repositories in parallel
    // Each will update the UI as soon as it completes
    final stopwatch = Stopwatch()..start();
    await Future.wait(
      repositories.map((repo) => refreshStatus(repo)),
    );
    stopwatch.stop();
    Logger.info('Analyzed ${repositories.length} repositories in ${stopwatch.elapsedMilliseconds}ms');
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
    StateNotifierProvider<RepositoryStatusNotifier, Map<String, RepositoryStatus>>((ref) {
  final notifier = RepositoryStatusNotifier(ref);

  // Check if config is ALREADY loaded (provider created after config finished loading)
  final configLoading = ref.read(configLoadingProvider);
  Logger.debug('[PROVIDER_INIT] workspaceRepositoryStatusProvider created, configLoading=$configLoading');

  if (!configLoading) {
    // Config already loaded before this provider was created
    // Trigger refresh immediately (after microtask to ensure provider is fully initialized)
    Logger.info('[PROVIDER_INIT] Config already loaded - scheduling immediate refresh');
    Future.microtask(() => notifier.refreshAll());
  }

  // Listen to config loading state for future changes
  // This handles the case where provider is created BEFORE config finishes loading
  ref.listen(configLoadingProvider, (previous, next) {
    Logger.debug('[LISTENER] Config loading state changed: previous=$previous, next=$next');
    if (previous == true && next == false) {
      // Config just finished loading - refresh all repository statuses
      Logger.info('[LISTENER] Config loaded - triggering repository status refresh');
      Future.microtask(() => notifier.refreshAll());
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
