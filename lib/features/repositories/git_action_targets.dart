/// Target resolution for the toolbar git actions.
///
/// The toolbar buttons stay visible even when they cannot run, so the rules
/// deciding between the multi-selection, the current repository and "nothing
/// to act on" live here as plain Dart instead of inside the widget tree,
/// where they could only be proven through widget tests.
library;

/// Why a toolbar git action cannot run right now, so its disabled button can
/// explain itself instead of silently disappearing.
enum GitActionBlock {
  /// No repositories are selected and no current repository is set.
  noRepository,

  /// The active selection resolves to repositories a single-repository
  /// action cannot handle.
  unsupportedSelection,
}

/// Resolves the effective target set of the toolbar git actions from the
/// repository multi-selection and the current repository.
class GitActionTargets {
  const GitActionTargets({
    required this.selectedPaths,
    required this.currentRepositoryPath,
  });

  /// Paths currently in the repository multi-selection.
  final Set<String> selectedPaths;

  /// Path of the repository the app currently has open, if any.
  final String? currentRepositoryPath;

  /// The selection wins over the current repository because selecting
  /// repositories is an explicit statement of intent while the current
  /// repository is ambient state; with neither there is nothing to act on
  /// and the buttons disable instead of hiding.
  List<String> get effectivePaths {
    if (selectedPaths.isNotEmpty) {
      return List.unmodifiable(selectedPaths);
    }
    final current = currentRepositoryPath;
    if (current != null) {
      return List.unmodifiable([current]);
    }
    return const [];
  }

  /// Fetch, pull, push and create-branch run per repository through the
  /// batch service, so any non-empty effective set is a valid target.
  GitActionBlock? get batchActionBlock =>
      effectivePaths.isEmpty ? GitActionBlock.noRepository : null;

  /// Pull-request creation opens one browser flow whose source, target and
  /// diff are inherently per-repository, so it accepts at most one target:
  /// a single selected repository, or the current one as fallback.
  GitActionBlock? get createPrBlock {
    if (selectedPaths.length > 1) {
      return GitActionBlock.unsupportedSelection;
    }
    if (selectedPaths.isEmpty && currentRepositoryPath == null) {
      return GitActionBlock.noRepository;
    }
    return null;
  }

  /// The merge dialog reads branches and conflict state from the current
  /// repository's providers, so merge may only run when the effective target
  /// is exactly that repository; anything else would merge a repository the
  /// user did not point at.
  GitActionBlock? get mergeBlock {
    final current = currentRepositoryPath;
    if (current == null) {
      return GitActionBlock.noRepository;
    }
    final targetsCurrentOnly =
        selectedPaths.isEmpty ||
        (selectedPaths.length == 1 && selectedPaths.contains(current));
    return targetsCurrentOnly ? null : GitActionBlock.unsupportedSelection;
  }
}
