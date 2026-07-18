import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/workspace_repository.dart';
import '../config/config_providers.dart';
import '../services/logger_service.dart';

/// Notifier for managing workspace repositories
/// This delegates all operations to ConfigNotifier to ensure single source of truth
class WorkspaceNotifier extends Notifier<List<WorkspaceRepository>> {
  @override
  List<WorkspaceRepository> build() {
    // Always return repositories from config (single source of truth)
    return ref.watch(workspaceConfigProvider).repositories;
  }

  /// Add a repository to the workspace
  Future<bool> addRepository(String path) async {
    // Normalize path
    final normalizedPath = path.replaceAll('\\', '/');

    // Check if already exists
    if (state.any((repo) => repo.path == normalizedPath)) {
      return false;
    }

    // Validate it's a Git repository
    final gitDir = Directory('$normalizedPath/.git');
    if (!await gitDir.exists()) {
      return false;
    }

    // Create repository
    final repo = WorkspaceRepository.fromPath(normalizedPath);

    // Add via config (single source of truth)
    await ref.read(configProvider.notifier).addRepository(repo);

    return true;
  }

  /// Add multiple repositories in a single batch operation
  /// Returns a list of results indicating success/failure for each path
  Future<List<BatchAddResult>> addRepositoriesBatch(List<String> paths) async {
    final results = <BatchAddResult>[];
    final reposToAdd = <WorkspaceRepository>[];

    // Validate all repositories in parallel
    final validations = await Future.wait(
      paths.map((path) => _validateRepository(path)),
    );

    // Collect valid repositories
    for (var i = 0; i < paths.length; i++) {
      final validation = validations[i];
      results.add(validation);

      if (validation.success && validation.repository != null) {
        reposToAdd.add(validation.repository!);
      }
    }

    // Add all valid repositories in a single write operation
    if (reposToAdd.isNotEmpty) {
      await ref.read(configProvider.notifier).addRepositoriesBatch(reposToAdd);
    }

    return results;
  }

  /// Validate a single repository path
  Future<BatchAddResult> _validateRepository(String path) async {
    try {
      // Normalize path
      final normalizedPath = path.replaceAll('\\', '/');

      // Check if already exists
      if (state.any((repo) => repo.path == normalizedPath)) {
        return BatchAddResult(
          path: path,
          success: false,
          error: 'Repository already exists',
          isDuplicate: true,
        );
      }

      // Check if it's a directory
      final dir = Directory(path);
      if (!await dir.exists()) {
        return BatchAddResult(
          path: path,
          success: false,
          error: 'Not a valid directory',
        );
      }

      // Validate it's a Git repository
      final gitDir = Directory('$normalizedPath/.git');
      if (!await gitDir.exists()) {
        return BatchAddResult(
          path: path,
          success: false,
          error: 'Not a Git repository',
        );
      }

      // Create repository
      final repo = WorkspaceRepository.fromPath(normalizedPath);

      return BatchAddResult(
        path: path,
        success: true,
        repository: repo,
      );
    } catch (e) {
      return BatchAddResult(
        path: path,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Remove a repository from the workspace
  Future<void> removeRepository(String path) async {
    // Check if the repository being removed is the current one
    final currentRepoPath = ref.read(currentRepositoryPathProvider);

    // Remove from config (this will trigger project cleanup via config listener)
    await ref.read(configProvider.notifier).removeRepository(path);

    // If we removed the current repository, clear the selection
    if (currentRepoPath == path) {
      await ref.read(configProvider.notifier).setCurrentRepository(null);
    }
  }

  /// Update repository details
  Future<void> updateRepository(
    String path, {
    String? customAlias,
    bool? isFavorite,
    String? description,
  }) async {
    await ref.read(configProvider.notifier).updateRepository(
      path,
      customAlias: customAlias,
      isFavorite: isFavorite,
      description: description,
    );
  }

  /// Update last accessed time for a repository
  Future<void> markAccessed(String path) async {
    await ref.read(configProvider.notifier).markRepositoryAccessed(path);
  }

  /// Get repositories sorted by last accessed (most recent first)
  List<WorkspaceRepository> getRecentRepositories() {
    final repos = [...state];
    repos.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    return repos;
  }

  /// Get favorite repositories
  List<WorkspaceRepository> getFavoriteRepositories() {
    return state.where((repo) => repo.isFavorite).toList();
  }

  /// Clear all repositories
  Future<void> clearAll() async {
    // Clear current repository selection FIRST
    await ref.read(configProvider.notifier).setCurrentRepository(null);

    // Then clear all repositories from config
    final reposToRemove = [...state]; // Create a copy to avoid modification during iteration
    for (final repo in reposToRemove) {
      await ref.read(configProvider.notifier).removeRepository(repo.path);
    }
  }

  /// Validate and clean up invalid repositories
  Future<void> validateRepositories() async {
    Logger.info('Validating ${state.length} repositories...');

    // Check each repository and collect invalid ones
    final invalidRepos = <WorkspaceRepository>[];
    for (final repo in state) {
      final isValid = repo.isValidGitRepo;
      Logger.debug('${repo.name}: ${isValid ? "valid" : "invalid (path: ${repo.path})"}');
      if (!isValid) {
        invalidRepos.add(repo);
      }
    }

    if (invalidRepos.isEmpty) {
      Logger.info('All repositories are valid');
      return; // No invalid repositories to remove
    }

    Logger.warning('Found ${invalidRepos.length} invalid repositories');

    // Check if current repository is invalid
    final currentRepoPath = ref.read(currentRepositoryPathProvider);
    final isCurrentRepoInvalid = invalidRepos.any((repo) => repo.path == currentRepoPath);

    // Clear current repository first if it's invalid
    if (isCurrentRepoInvalid) {
      Logger.info('Clearing current repository selection (was invalid)');
      await ref.read(configProvider.notifier).setCurrentRepository(null);
    }

    // Remove invalid ones from config
    for (final repo in invalidRepos) {
      Logger.info('Removing: ${repo.name}');
      await ref.read(configProvider.notifier).removeRepository(repo.path);
    }

    Logger.info('Validation complete');
  }
}

/// Provider for workspace repositories (reads from config)
final workspaceProvider = NotifierProvider<WorkspaceNotifier, List<WorkspaceRepository>>(
  WorkspaceNotifier.new,
);

/// Provider to get recent repositories
final recentRepositoriesProvider = Provider<List<WorkspaceRepository>>((ref) {
  final workspace = ref.watch(workspaceProvider.notifier);
  return workspace.getRecentRepositories();
});

/// Provider to get favorite repositories
final favoriteRepositoriesProvider = Provider<List<WorkspaceRepository>>((ref) {
  final workspace = ref.watch(workspaceProvider);
  return workspace.where((repo) => repo.isFavorite).toList();
});

/// Provider to get current repository
final currentWorkspaceRepositoryProvider = Provider<WorkspaceRepository?>((ref) {
  final currentPath = ref.watch(currentRepositoryPathProvider);
  if (currentPath == null) return null;

  final workspace = ref.watch(workspaceProvider);
  try {
    return workspace.firstWhere((repo) => repo.path == currentPath);
  } catch (_) {
    return null;
  }
});

/// Result of a batch repository add operation
class BatchAddResult {
  final String path;
  final bool success;
  final String? error;
  final bool isDuplicate;
  final WorkspaceRepository? repository;

  const BatchAddResult({
    required this.path,
    required this.success,
    this.error,
    this.isDuplicate = false,
    this.repository,
  });
}
