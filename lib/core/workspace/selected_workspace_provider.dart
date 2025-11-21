import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import 'workspace_list_provider.dart';
import 'models/workspace.dart';
import '../config/config_providers.dart';

/// Provider for the currently selected project (stored in YAML)
final selectedProjectProvider = StateNotifierProvider<SelectedProjectNotifier, Workspace?>((ref) {
  return SelectedProjectNotifier(ref);
});

/// Notifier for managing the selected project
class SelectedProjectNotifier extends StateNotifier<Workspace?> {
  final Ref ref;

  SelectedProjectNotifier(this.ref) : super(null) {
    _loadSelectedProject();

    // Listen to repository changes and update the project's last selected repository
    ref.listen<String?>(currentRepositoryPathProvider, (previous, next) {
      _onRepositoryChanged(next);
    });
  }

  /// Update the project's last selected repository when repository changes
  /// Uses Future.microtask to defer the update until after the current build phase
  void _onRepositoryChanged(String? repositoryPath) {
    if (state != null) {
      // Defer the update to avoid modifying providers during build phase
      Future.microtask(() {
        ref.read(projectProvider.notifier).updateLastSelectedRepository(state!.id, repositoryPath);
      });
    }
  }

  /// Load selected project from YAML config
  void _loadSelectedProject() {
    final projects = ref.read(projectProvider);
    final config = ref.read(configProvider);
    final selectedId = config.workspace.selectedWorkspaceId;

    if (projects.isEmpty) {
      state = null;
      return;
    }

    // Try to find the selected project by ID
    if (selectedId != null) {
      final project = projects.where((p) => p.id == selectedId).firstOrNull;
      if (project != null) {
        state = project;
        return;
      }
    }

    // Otherwise select default project or first project
    final defaultWorkspace = projects.where((p) => p.id == 'default').firstOrNull;
    state = defaultWorkspace ?? projects.first;

    // Don't save during initialization - only save when user makes explicit selection
    // The selected project will be saved when the user first changes project selection
  }

  /// Save selected project ID to YAML config
  Future<void> _saveSelectedProject() async {
    if (state == null) return;
    await ref.read(configProvider.notifier).updateSelectedWorkspaceId(state!.id);
  }

  /// Select a project
  Future<void> selectProject(Workspace project) async {
    // Save the current repository to the current project before switching
    final currentRepoPath = ref.read(currentRepositoryPathProvider);
    if (state != null && currentRepoPath != null && state!.containsRepository(currentRepoPath)) {
      await ref.read(projectProvider.notifier).updateLastSelectedRepository(state!.id, currentRepoPath);
    }

    state = project;
    await _saveSelectedProject();

    // Restore the last selected repository for this project
    if (project.lastSelectedRepository != null && project.containsRepository(project.lastSelectedRepository!)) {
      // Restore the last selected repository if it still exists in the project
      await ref.read(configProvider.notifier).setCurrentRepository(project.lastSelectedRepository);
    } else if (project.repositoryPaths.length == 1) {
      // If project has only one repository, automatically select it
      await ref.read(configProvider.notifier).setCurrentRepository(project.repositoryPaths.first);
    } else {
      // Check if current repository belongs to this project
      if (currentRepoPath != null && !project.containsRepository(currentRepoPath)) {
        // Close the current repository if it doesn't belong to the selected project
        await ref.read(configProvider.notifier).setCurrentRepository(null);
      }
    }
  }

  /// Clear selection
  Future<void> clearSelection() async {
    state = null;
    await ref.read(configProvider.notifier).updateSelectedWorkspaceId(null);
  }

  /// Select project by ID
  Future<void> selectProjectById(String projectId) async {
    final projects = ref.read(projectProvider);
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    if (project != null) {
      await selectProject(project);
    }
  }
}
