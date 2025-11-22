import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/workspace.dart';
import 'workspace_list_provider.dart';
import 'workspace_provider.dart';

/// Provider for getting project for a specific repository
final projectForRepositoryProvider = Provider.family<Workspace?, String>((ref, repositoryPath) {
  final projects = ref.watch(projectProvider);
  try {
    return projects.firstWhere((project) => project.containsRepository(repositoryPath));
  } catch (e) {
    return null;
  }
});

/// Provider for repositories not assigned to any project
final unassignedRepositoriesProvider = Provider<List<String>>((ref) {
  final projects = ref.watch(projectProvider);
  final allRepos = ref.watch(workspaceProvider);

  final assignedPaths = projects
      .expand((project) => project.repositoryPaths)
      .toSet();

  return allRepos
      .where((repo) => !assignedPaths.contains(repo.path))
      .map((repo) => repo.path)
      .toList();
});
