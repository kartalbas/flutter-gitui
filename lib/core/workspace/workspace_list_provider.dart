import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import 'models/workspace.dart';
import 'selected_workspace_provider.dart';
import '../config/config_providers.dart';
import '../config/app_config.dart';
import '../services/logger_service.dart';

/// Provider for managing workspaces (stored in YAML config file)
final projectProvider = StateNotifierProvider<ProjectNotifier, List<Workspace>>((ref) {
  return ProjectNotifier(ref);
});

/// Notifier for managing workspaces
class ProjectNotifier extends StateNotifier<List<Workspace>> {
  final Ref ref;
  final _uuid = const Uuid();
  bool _isSaving = false;

  ProjectNotifier(this.ref) : super([]) {
    // Watch config provider so we reload when config changes
    ref.listen(configProvider, (previous, next) {
      // Don't reload if we're the one who triggered the save
      if (_isSaving) {
        Logger.debug('ProjectNotifier: Config changed due to our own save, ignoring');
        return;
      }
      Logger.debug('ProjectNotifier: Config changed externally, reloading projects');
      _loadProjects();
    });
    _loadProjects();
  }

  /// Load workspaces from YAML config
  void _loadProjects() {
    final config = ref.read(configProvider);
    Logger.debug('ProjectNotifier._loadProjects: Loading ${config.workspace.workspaces.length} workspaces from config');
    for (final p in config.workspace.workspaces) {
      Logger.debug('- ${p.name} (${p.id}) with ${p.repositoryPaths.length} repos');
    }

    state = config.workspace.workspaces.map(_fromWorkspaceConfigEntry).toList();
    Logger.debug('ProjectNotifier state now has ${state.length} workspaces');

    // Ensure default workspace exists (but don't save during initialization)
    final hasDefaultWorkspace = state.any((p) => p.id == 'default');
    if (!hasDefaultWorkspace) {
      Logger.info('No default workspace found, creating one');
      final defaultWorkspace = Workspace(
        id: 'default',
        name: 'Default',
        description: 'Default workspace for all repositories',
        color: WorkspaceColors.defaults[0],
        repositoryPaths: [],
        createdAt: DateTime.now(),
      );
      state = [defaultWorkspace, ...state];

      // Don't save during initialization - only save when user makes explicit changes
      // The default workspace will be saved when the user first modifies workspaces
    }
  }

  /// Convert WorkspaceConfigEntry to Workspace
  Workspace _fromWorkspaceConfigEntry(WorkspaceConfigEntry wp) {
    return Workspace(
      id: wp.id,
      name: wp.name,
      description: wp.description,
      color: Color(wp.color),
      icon: wp.icon,
      repositoryPaths: wp.repositoryPaths,
      lastSelectedRepository: wp.lastSelectedRepository,
      createdAt: DateTime.parse(wp.createdAt),
      updatedAt: wp.updatedAt != null ? DateTime.parse(wp.updatedAt!) : null,
    );
  }

  /// Convert Workspace to WorkspaceConfigEntry
  WorkspaceConfigEntry _toWorkspaceConfigEntry(Workspace p) {
    return WorkspaceConfigEntry(
      id: p.id,
      name: p.name,
      description: p.description,
      color: p.color.toARGB32(),
      icon: p.icon,
      repositoryPaths: p.repositoryPaths,
      lastSelectedRepository: p.lastSelectedRepository,
      createdAt: p.createdAt.toIso8601String(),
      updatedAt: p.updatedAt?.toIso8601String(),
    );
  }

  /// Save workspaces to YAML config using the SINGLE config provider
  Future<void> _saveProjects() async {
    _isSaving = true;
    try {
      final workspaceEntries = state.map(_toWorkspaceConfigEntry).toList();
      await ref.read(configProvider.notifier).updateWorkspaces(workspaceEntries);
    } finally {
      // Reset flag after a small delay to ensure config change propagates
      Future.delayed(const Duration(milliseconds: 100), () {
        _isSaving = false;
      });
    }
  }

  /// Assign unassigned repositories to a project (usually default)
  Future<void> assignUnassignedRepositories(List<String> allRepoPaths, String projectId) async {
    // Get repository paths that are already assigned to projects
    final assignedPaths = state
        .expand((project) => project.repositoryPaths)
        .toSet();

    // Find unassigned repositories
    final unassignedPaths = allRepoPaths
        .where((path) => !assignedPaths.contains(path))
        .toList();

    // Add unassigned repos to the specified project
    if (unassignedPaths.isNotEmpty) {
      state = state.map((project) {
        if (project.id == projectId) {
          return project.copyWith(
            repositoryPaths: [...project.repositoryPaths, ...unassignedPaths],
            updatedAt: DateTime.now(),
          );
        }
        return project;
      }).toList();

      await _saveProjects();

      // Refresh selected project if it's the one being modified
      final selectedWorkspace = ref.read(selectedProjectProvider);
      if (selectedWorkspace?.id == projectId) {
        final updatedWorkspace = state.firstWhere((p) => p.id == projectId);
        ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
      }
    }
  }

  /// Create a new project
  Future<Workspace> createWorkspace({
    required String name,
    String? description,
    required Color color,
    String? icon,
  }) async {
    final project = Workspace(
      id: _uuid.v4(),
      name: name,
      description: description,
      color: color,
      icon: icon,
      repositoryPaths: [],
      createdAt: DateTime.now(),
    );

    state = [...state, project];
    await _saveProjects();
    return project;
  }

  /// Update an existing project
  Future<void> updateWorkspace(String projectId, {
    String? name,
    String? description,
    Color? color,
    String? icon,
  }) async {
    state = state.map((project) {
      if (project.id == projectId) {
        return project.copyWith(
          name: name,
          description: description,
          color: color,
          icon: icon,
          updatedAt: DateTime.now(),
        );
      }
      return project;
    }).toList();

    await _saveProjects();

    // Refresh selected project if it's the one being modified
    final selectedWorkspace = ref.read(selectedProjectProvider);
    if (selectedWorkspace?.id == projectId) {
      final updatedWorkspace = state.firstWhere((p) => p.id == projectId);
      ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
    }
  }

  /// Delete a project
  /// Note: The default project cannot be deleted
  Future<void> deleteWorkspace(String projectId) async {
    if (projectId == 'default') {
      throw Exception('The default project cannot be deleted');
    }

    state = state.where((project) => project.id != projectId).toList();
    await _saveProjects();
  }

  /// Add a repository to a project
  Future<void> addRepositoryToWorkspace(String projectId, String repositoryPath) async {
    state = state.map((project) {
      if (project.id == projectId) {
        return project.addRepository(repositoryPath);
      }
      return project;
    }).toList();

    await _saveProjects();

    // Refresh selected project if it's the one being modified
    final selectedWorkspace = ref.read(selectedProjectProvider);
    if (selectedWorkspace?.id == projectId) {
      final updatedWorkspace = state.firstWhere((p) => p.id == projectId);
      ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
    }
  }

  /// Add multiple repositories to a project in a single batch operation
  Future<void> addRepositoriesToWorkspaceBatch(String projectId, List<String> repositoryPaths) async {
    if (repositoryPaths.isEmpty) return;

    state = state.map((project) {
      if (project.id == projectId) {
        var updatedProject = project;
        for (final path in repositoryPaths) {
          updatedProject = updatedProject.addRepository(path);
        }
        return updatedProject;
      }
      return project;
    }).toList();

    // Single save operation
    await _saveProjects();

    // Refresh selected project if it's the one being modified
    final selectedWorkspace = ref.read(selectedProjectProvider);
    if (selectedWorkspace?.id == projectId) {
      final updatedWorkspace = state.firstWhere((p) => p.id == projectId);
      ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
    }
  }

  /// Remove a repository from a project
  Future<void> removeRepositoryFromWorkspace(String projectId, String repositoryPath) async {
    state = state.map((project) {
      if (project.id == projectId) {
        return project.removeRepository(repositoryPath);
      }
      return project;
    }).toList();

    await _saveProjects();

    // Refresh selected project if it's the one being modified
    final selectedWorkspace = ref.read(selectedProjectProvider);
    if (selectedWorkspace?.id == projectId) {
      final updatedWorkspace = state.firstWhere((p) => p.id == projectId);
      ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
    }
  }

  /// Move a repository from one project to another
  Future<void> moveRepository(
    String repositoryPath,
    String? fromProjectId,
    String? toProjectId,
  ) async {
    state = state.map((project) {
      // Remove from source project
      if (fromProjectId != null && project.id == fromProjectId) {
        return project.removeRepository(repositoryPath);
      }
      // Add to destination project
      if (toProjectId != null && project.id == toProjectId) {
        return project.addRepository(repositoryPath);
      }
      return project;
    }).toList();

    await _saveProjects();

    // Refresh selected project if it's one of the projects being modified
    final selectedWorkspace = ref.read(selectedProjectProvider);
    if (selectedWorkspace != null &&
        (selectedWorkspace.id == fromProjectId || selectedWorkspace.id == toProjectId)) {
      final updatedWorkspace = state.firstWhere((p) => p.id == selectedWorkspace.id);
      ref.read(selectedProjectProvider.notifier).selectProject(updatedWorkspace);
    }
  }

  /// Get project by ID
  Workspace? getWorkspace(String projectId) {
    try {
      return state.firstWhere((project) => project.id == projectId);
    } catch (e) {
      return null;
    }
  }

  /// Get project containing a repository
  Workspace? getProjectForRepository(String repositoryPath) {
    try {
      return state.firstWhere((project) => project.containsRepository(repositoryPath));
    } catch (e) {
      return null;
    }
  }

  /// Update the last selected repository for a project
  Future<void> updateLastSelectedRepository(String projectId, String? repositoryPath) async {
    state = state.map((project) {
      if (project.id == projectId) {
        return project.copyWith(
          lastSelectedRepository: repositoryPath,
          updatedAt: DateTime.now(),
        );
      }
      return project;
    }).toList();

    await _saveProjects();
  }

  /// Refresh projects from config file
  void refresh() {
    _loadProjects();
  }
}
