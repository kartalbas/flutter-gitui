import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../git/git_repository_watcher.dart';
import '../services/logger_service.dart';
import 'workspace_provider.dart';
import 'repository_status_provider.dart';
import 'models/workspace_repository.dart';

/// Manages file watchers for all repositories in the workspace
class WorkspaceRepositoryWatchersNotifier extends StateNotifier<Map<String, GitRepositoryWatcher>> {
  final Ref ref;

  WorkspaceRepositoryWatchersNotifier(this.ref) : super({});

  /// Initialize watchers for all repositories
  Future<void> initializeWatchers() async {
    final repositories = ref.read(workspaceProvider);

    // Dispose existing watchers
    for (final watcher in state.values) {
      await watcher.stop();
    }

    // Create new watchers for each repository
    final newWatchers = <String, GitRepositoryWatcher>{};

    for (final repo in repositories) {
      final watcher = GitRepositoryWatcher(
        repositoryPath: repo.path,
        onRepositoryChanged: () async {
          Logger.debug('[WATCHER] Repository changed: ${repo.displayName}');
          // Refresh status only for this specific repository
          await ref.read(workspaceRepositoryStatusProvider.notifier).refreshStatus(repo);
        },
      );

      await watcher.start();
      newWatchers[repo.path] = watcher;
      Logger.debug('[WATCHER] Started watching: ${repo.displayName}');
    }

    state = newWatchers;
    Logger.info('[WATCHER] Initialized ${newWatchers.length} repository watchers');
  }

  /// Add a watcher for a new repository
  Future<void> addWatcher(WorkspaceRepository repository) async {
    // Skip if already watching
    if (state.containsKey(repository.path)) {
      return;
    }

    final watcher = GitRepositoryWatcher(
      repositoryPath: repository.path,
      onRepositoryChanged: () async {
        Logger.debug('[WATCHER] Repository changed: ${repository.displayName}');
        await ref.read(workspaceRepositoryStatusProvider.notifier).refreshStatus(repository);
      },
    );

    await watcher.start();
    state = {...state, repository.path: watcher};
    Logger.debug('[WATCHER] Added watcher for: ${repository.displayName}');
  }

  /// Remove a watcher for a repository
  Future<void> removeWatcher(String path) async {
    final watcher = state[path];
    if (watcher != null) {
      await watcher.stop();
      final newState = Map<String, GitRepositoryWatcher>.from(state);
      newState.remove(path);
      state = newState;
      Logger.debug('[WATCHER] Removed watcher for: $path');
    }
  }

  /// Dispose all watchers
  Future<void> disposeAll() async {
    for (final watcher in state.values) {
      await watcher.stop();
    }
    state = {};
    Logger.info('[WATCHER] Disposed all repository watchers');
  }
}

/// Provider for workspace repository watchers
final workspaceRepositoryWatchersProvider =
    StateNotifierProvider<WorkspaceRepositoryWatchersNotifier, Map<String, GitRepositoryWatcher>>((ref) {
  final notifier = WorkspaceRepositoryWatchersNotifier(ref);

  // Initialize watchers after status provider has done its initial refresh
  // Use addPostFrameCallback to ensure it runs after the build phase
  Future.microtask(() async {
    // Wait a bit for the status provider to finish its initial refresh
    await Future.delayed(const Duration(milliseconds: 500));
    await notifier.initializeWatchers();
  });

  // Listen for workspace changes and update watchers accordingly
  ref.listen(workspaceProvider, (previous, next) async {
    if (previous == null || next.isEmpty) return;

    final previousPaths = previous.map((r) => r.path).toSet();
    final nextPaths = next.map((r) => r.path).toSet();

    // Find added and removed repositories
    final added = nextPaths.difference(previousPaths);
    final removed = previousPaths.difference(nextPaths);

    // Add watchers for new repositories
    for (final path in added) {
      final repo = next.firstWhere((r) => r.path == path);
      await notifier.addWatcher(repo);
    }

    // Remove watchers for deleted repositories
    for (final path in removed) {
      await notifier.removeWatcher(path);
    }
  });

  // Cleanup on dispose
  ref.onDispose(() async {
    await notifier.disposeAll();
  });

  return notifier;
});
