import 'package:riverpod/legacy.dart';
import '../../core/workspace/models/workspace_repository.dart';

/// Provider for managing multi-selection of repositories in the dashboard
class RepositoryMultiSelectNotifier extends StateNotifier<Set<String>> {
  RepositoryMultiSelectNotifier() : super({});

  /// Toggle selection of a repository
  void toggleSelection(WorkspaceRepository repository) {
    if (state.contains(repository.path)) {
      state = {...state}..remove(repository.path);
    } else {
      state = {...state, repository.path};
    }
  }

  /// Select a repository
  void select(WorkspaceRepository repository) {
    if (!state.contains(repository.path)) {
      state = {...state, repository.path};
    }
  }

  /// Deselect a repository
  void deselect(WorkspaceRepository repository) {
    if (state.contains(repository.path)) {
      state = {...state}..remove(repository.path);
    }
  }

  /// Select all repositories
  void selectAll(List<WorkspaceRepository> repositories) {
    state = repositories.map((r) => r.path).toSet();
  }

  /// Clear all selections
  void clearSelection() {
    state = {};
  }

  /// Check if a repository is selected
  bool isSelected(WorkspaceRepository repository) {
    return state.contains(repository.path);
  }

  /// Get count of selected repositories
  int get selectedCount => state.length;

  /// Check if any repositories are selected
  bool get hasSelection => state.isNotEmpty;
}

/// Provider for repository multi-selection
final repositoryMultiSelectProvider =
    StateNotifierProvider<RepositoryMultiSelectNotifier, Set<String>>((ref) {
      return RepositoryMultiSelectNotifier();
    });
