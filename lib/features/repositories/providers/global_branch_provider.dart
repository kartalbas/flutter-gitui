import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/workspace/workspace_provider.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/workspace/selected_workspace_provider.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/git_service.dart';
import '../../../core/git/models/branch.dart';
import '../../../core/services/logger_service.dart';

/// Information about a branch across repositories
class GlobalBranchInfo {
  final String branchName;
  final int repositoryCount; // How many repos have this branch
  final int totalRepositories; // Total repos in workspace
  final List<String> repositoryPaths; // Paths of repos that have this branch
  final List<String> repositoryNames; // Display names of repos that have this branch

  const GlobalBranchInfo({
    required this.branchName,
    required this.repositoryCount,
    required this.totalRepositories,
    required this.repositoryPaths,
    required this.repositoryNames,
  });

  /// Get display text showing branch name with count
  String get displayText => '$branchName ($repositoryCount/$totalRepositories repos)';

  /// Check if this branch exists in all repositories
  bool get existsInAll => repositoryCount == totalRepositories;
}

/// Provider that aggregates all unique branches across all repositories
/// Rebuilds when:
/// 1. Selected project changes
/// 2. Any repository's current branch changes (branch checkout)
/// Does NOT rebuild when selecting a repository (only metadata change)
final globalBranchesProvider = FutureProvider<List<GlobalBranchInfo>>((ref) async {
  Logger.debug('[GlobalBranch] Provider rebuilding...');

  // Watch only repository paths as a string key to avoid rebuilds on metadata changes (e.g., lastAccessed)
  // This ensures rebuilds only happen when repos are added/removed, not when selected
  // Using string comparison for value equality instead of list reference equality
  final repositoryPathsKey = ref.watch(
    workspaceProvider.select((repos) {
      final paths = repos.map((r) => r.path).toList()..sort();
      return paths.join('|');
    }),
  );
  Logger.debug('[GlobalBranch] repositoryPathsKey hash: ${repositoryPathsKey.hashCode}');

  // Read full repo objects for processing (don't watch to avoid metadata rebuilds)
  final allRepositories = ref.read(workspaceProvider);

  final gitExecutablePath = ref.watch(gitExecutablePathProvider);
  Logger.debug('[GlobalBranch] gitExecutablePath: $gitExecutablePath');

  // Watch protected branches config - only show protected branches for cross-repo checkout
  final protectedBranches = ref.watch(configProvider.select((c) => c.git.protectedBranches));
  Logger.debug('[GlobalBranch] protectedBranches: $protectedBranches');

  // Watch selected project ID - rebuild when project changes
  final selectedProjectId = ref.watch(selectedProjectProvider.select((p) => p?.id));
  Logger.debug('[GlobalBranch] selectedProjectId: $selectedProjectId');

  final selectedProject = ref.read(selectedProjectProvider);

  // Watch current branches - rebuild when any repo changes branch
  // Create a sorted string representation for equality comparison
  final currentBranchesKey = ref.watch(
    workspaceRepositoryStatusProvider.select((statuses) {
      final entries = statuses.entries
          .map((e) => '${e.key}:${e.value.currentBranch ?? ""}')
          .toList()
        ..sort();
      return entries.join('|');
    }),
  );
  Logger.debug('[GlobalBranch] currentBranchesKey hash: ${currentBranchesKey.hashCode}');

  // Read full statuses for processing (don't watch to avoid rebuilds on metadata changes)
  final statuses = ref.read(workspaceRepositoryStatusProvider);

  if (allRepositories.isEmpty) return [];

  // Filter repositories to only those in the selected project
  final repositories = selectedProject != null
      ? allRepositories.where((repo) => selectedProject.containsRepository(repo.path)).toList()
      : allRepositories;

  if (repositories.isEmpty) return [];

  // Maps to track branches and repository states
  final allBranches = <String>{};  // All unique branch names across all repos
  final repoCurrentBranches = <String, String>{};  // repo path -> current branch
  final repoAvailableBranches = <String, Set<String>>{};  // repo path -> available branches

  // Query each repository for its branches
  for (final repo in repositories) {
    final status = statuses[repo.path];

    // Track current branch
    if (status != null && !status.isLoading) {
      final currentBranch = status.currentBranch;
      if (currentBranch != null && currentBranch.isNotEmpty) {
        repoCurrentBranches[repo.path] = currentBranch;
        allBranches.add(currentBranch);
      }
    }

    // Query all available branches for this repo
    try {
      final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
      final branches = await gitService.getBranches();
      repoAvailableBranches[repo.path] = branches.toSet();
      allBranches.addAll(branches);
    } catch (e) {
      // Skip repos with git errors
      continue;
    }
  }

  // For each branch, find repos that are NOT on it but HAVE it available
  final branchesToSwitch = <String, List<String>>{};
  final branchNamesMap = <String, List<String>>{};

  for (final branchName in allBranches) {
    final reposNotOnBranch = <String>[];
    final repoNamesNotOnBranch = <String>[];

    for (final repo in repositories) {
      final currentBranch = repoCurrentBranches[repo.path];
      final availableBranches = repoAvailableBranches[repo.path] ?? {};

      // Skip repos where we don't know the current branch
      if (currentBranch == null) continue;

      // Only include if repo is NOT on this branch AND has this branch available
      if (currentBranch != branchName && availableBranches.contains(branchName)) {
        reposNotOnBranch.add(repo.path);
        repoNamesNotOnBranch.add(repo.displayName);
      }
    }

    if (reposNotOnBranch.isNotEmpty) {
      branchesToSwitch[branchName] = reposNotOnBranch;
      branchNamesMap[branchName] = repoNamesNotOnBranch;
    }
  }

  // Convert to GlobalBranchInfo list
  final branches = branchesToSwitch.entries.map((entry) {
    return GlobalBranchInfo(
      branchName: entry.key,
      repositoryCount: entry.value.length,  // Count of repos that can switch
      totalRepositories: repositories.length,
      repositoryPaths: entry.value,  // Repos that are NOT on this branch
      repositoryNames: branchNamesMap[entry.key] ?? [],
    );
  }).toList();

  // Filter to only show protected branches for cross-repository checkout
  // This limits the global switcher to safe branches like main, master, develop, etc.
  final protectedBranchesOnly = branches.where((branch) {
    return GitBranch.isProtectedBranch(branch.branchName, protectedBranches);
  }).toList();

  // Sort by count (descending), then by name
  protectedBranchesOnly.sort((a, b) {
    final countCompare = b.repositoryCount.compareTo(a.repositoryCount);
    if (countCompare != 0) return countCompare;
    return a.branchName.compareTo(b.branchName);
  });

  Logger.debug('[GlobalBranch] Found ${protectedBranchesOnly.length} protected branches for cross-repo checkout');

  return protectedBranchesOnly;
});

/// Provider for currently selected global branch
final selectedGlobalBranchProvider = StateProvider<String?>((ref) => null);

/// Provider to get the most common branch (the one that can be switched in most repositories)
final mostCommonBranchProvider = Provider<String?>((ref) {
  final branchesAsync = ref.watch(globalBranchesProvider);
  return branchesAsync.maybeWhen(
    data: (branches) => branches.isEmpty ? null : branches.first.branchName,
    orElse: () => null,
  );
});
