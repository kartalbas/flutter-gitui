import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_dialog.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/git_service.dart';
import '../../core/config/config_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../../core/workspace/models/repository_status.dart';
import '../../core/workspace/repository_status_provider.dart';
import '../../core/services/logger_service.dart';
import '../../core/navigation/navigation_item.dart';
import '../../shared/dialogs/clone_repository_dialog.dart';
import '../../shared/dialogs/initialize_repository_dialog.dart';
import '../../shared/dialogs/edit_remote_url_dialog.dart';
import '../../shared/dialogs/rename_remote_dialog.dart';
import '../../shared/dialogs/prune_remote_dialog.dart';
import '../../core/services/notification_service.dart';
import 'widgets/repository_card.dart';
import 'widgets/repository_list_item.dart';
import 'widgets/repositories_filter_chips.dart';
import 'widgets/repositories_empty_state.dart';
import 'repository_multi_select_provider.dart';

/// Repositories screen - Workspace repositories and quick actions
class RepositoriesScreen extends ConsumerStatefulWidget {
  const RepositoriesScreen({super.key});

  @override
  ConsumerState<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends ConsumerState<RepositoriesScreen> {
  bool _isDragging = false;
  int _lastRepositoryCount = 0;
  bool _hasAssignedRepos = false;

  // Filter states
  bool _filterCleanOnly = false;
  bool _filterWithRemote = false;

  @override
  void initState() {
    super.initState();
    // Initial trigger will happen in build after repositories are loaded
  }

  List<WorkspaceRepository> _applyFilters(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses,
  ) {
    var filtered = repositories;

    if (_filterCleanOnly) {
      filtered = filtered.where((repo) {
        final status = statuses[repo.path];
        return !(status?.hasUncommittedChanges ?? false);
      }).toList();
    }

    if (_filterWithRemote) {
      filtered = filtered.where((repo) {
        final status = statuses[repo.path];
        return status?.hasRemote ?? false;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allRepositories = ref.watch(workspaceProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final statuses = ref.watch(workspaceRepositoryStatusProvider);
    final selectedPaths = ref.watch(repositoryMultiSelectProvider);

    // Filter repositories by selected project
    final repositories = selectedProject != null
        ? allRepositories.where((repo) {
            // Special handling for default project: show all unassigned repos
            if (selectedProject.id == 'default') {
              // Check if this repo is assigned to any other project
              final projects = ref.read(projectProvider);
              final isAssignedToOther = projects
                  .where((p) => p.id != 'default')
                  .any((p) => p.containsRepository(repo.path));

              // Show if not assigned to other projects OR explicitly assigned to default
              final shouldShow = !isAssignedToOther || selectedProject.containsRepository(repo.path);

              if (kDebugMode) {
                Logger.debug('[Default Project] Repo "${repo.path}" - assigned to other: $isAssignedToOther, in default: ${selectedProject.containsRepository(repo.path)}, showing: $shouldShow');
              }
              return shouldShow;
            }

            // For non-default projects, only show explicitly assigned repos
            final contains = selectedProject.containsRepository(repo.path);
            if (kDebugMode) {
              Logger.debug('Filtering repo "${repo.path}" for project "${selectedProject.name}": $contains');
            }
            return contains;
          }).toList()
        : allRepositories;

    final hasRepositories = repositories.isNotEmpty;

    // Apply filters
    final filteredRepositories = _applyFilters(repositories, statuses);
    final selectedRepositories = repositories.where((r) => selectedPaths.contains(r.path)).toList();

    // Assign unassigned repositories to default project on first load
    if (!_hasAssignedRepos && allRepositories.isNotEmpty && selectedProject != null) {
      _hasAssignedRepos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final allRepoPaths = allRepositories.map((r) => r.path).toList();
        await ref.read(projectProvider.notifier).assignUnassignedRepositories(
          allRepoPaths,
          selectedProject.id,
        );
      });
    }

    // Trigger analysis when repositories are loaded or changed
    // Use postFrameCallback to avoid state changes during build
    // GUARD: Only trigger if config has finished loading (prevents broken repos on startup)
    final configLoading = ref.watch(configLoadingProvider);
    if (repositories.length != _lastRepositoryCount && !configLoading) {
      _lastRepositoryCount = repositories.length;
      if (hasRepositories) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
        });
      }
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleDroppedFiles(details),
      child: Stack(
        children: [
          // Main content
          Scaffold(
            appBar: StandardAppBar(
              title: AppDestination.repositories.label(context),
              additionalActions: hasRepositories
                  ? [
                      // View mode toggle
                      Consumer(
                        builder: (context, ref, child) {
                          final viewMode = ref.watch(repositoriesViewModeProvider);
                          return SegmentedButton<RepositoriesViewMode>(
                            segments: const [
                              ButtonSegment(
                                value: RepositoriesViewMode.grid,
                                icon: Icon(PhosphorIconsRegular.gridFour, size: 18),
                              ),
                              ButtonSegment(
                                value: RepositoriesViewMode.list,
                                icon: Icon(PhosphorIconsRegular.listBullets, size: 18),
                              ),
                            ],
                            selected: {viewMode},
                            onSelectionChanged: (Set<RepositoriesViewMode> newSelection) {
                              ref.read(configProvider.notifier).setRepositoriesViewMode(newSelection.first);
                            },
                          );
                        },
                      ),
                      const SizedBox(width: AppTheme.paddingM),
                    ]
                  : null,
              moreMenuItems: [
                // Add repository action (first)
                PopupMenuItem<String>(
                  value: 'add',
                  child: MenuItemContent(
                    icon: PhosphorIconsRegular.plus,
                    label: AppLocalizations.of(context)!.tooltipAddRepository,
                    iconSize: 20,
                  ),
                  onTap: () => _openRepository(context, ref),
                ),
                const PopupMenuDivider(),
                // Clone action
                PopupMenuItem<String>(
                  value: 'clone',
                  child: MenuItemContent(
                    icon: PhosphorIconsRegular.downloadSimple,
                    label: AppLocalizations.of(context)!.cloneRepository,
                    iconSize: 20,
                  ),
                  onTap: () => _showCloneDialog(context),
                ),
                // Initialize action
                PopupMenuItem<String>(
                  value: 'init',
                  child: MenuItemContent(
                    icon: PhosphorIconsRegular.folderPlus,
                    label: AppLocalizations.of(context)!.initializeRepository,
                    iconSize: 20,
                  ),
                  onTap: () => _showInitDialog(context),
                ),
                const PopupMenuDivider(),
                // Validate action
                PopupMenuItem<String>(
                  value: 'validate',
                  child: MenuItemContent(
                    icon: PhosphorIconsRegular.checkCircle,
                    label: AppLocalizations.of(context)!.validateAll,
                    iconSize: 20,
                  ),
                  onTap: () => _validateRepositories(ref),
                ),
                // Remove all from workspace (conditional)
                if (hasRepositories)
                  PopupMenuItem<String>(
                    value: 'clear',
                    child: MenuItemContent(
                      icon: PhosphorIconsRegular.trash,
                      label: AppLocalizations.of(context)!.clearAllRepositories,
                      iconSize: 20,
                      iconColor: Theme.of(context).colorScheme.error,
                      labelColor: Theme.of(context).colorScheme.error,
                    ),
                    onTap: () => _confirmClearAll(context, ref),
                  ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                // Filter chips and selection info
                if (hasRepositories) ...[
                  RepositoriesFilterChips(
                    filterCleanOnly: _filterCleanOnly,
                    filterWithRemote: _filterWithRemote,
                    onFilterCleanOnlyChanged: (value) {
                      setState(() {
                        _filterCleanOnly = value;
                      });
                    },
                    onFilterWithRemoteChanged: (value) {
                      setState(() {
                        _filterWithRemote = value;
                      });
                    },
                    filteredRepositories: filteredRepositories,
                    selectedRepositories: selectedRepositories,
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                ],

                  // Content
                  Expanded(
                    child: hasRepositories
                        ? Consumer(
                            builder: (context, ref, child) {
                              final viewMode = ref.watch(repositoriesViewModeProvider);
                              return viewMode == RepositoriesViewMode.grid
                                  ? _buildRepositoryGrid(context, ref, filteredRepositories)
                                  : _buildRepositoryList(context, ref, filteredRepositories);
                            },
                          )
                        : RepositoriesEmptyState(
                            onOpenRepository: () => _openRepository(context, ref),
                            onCloneRepository: () => _showCloneDialog(context),
                            onInitRepository: () => _showInitDialog(context),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Drag overlay
          if (_isDragging)
            Container(
              color: Theme.of(context).colorScheme.primary.withValues(alpha:0.1),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.paddingXL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsBold.folderOpen,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppTheme.paddingM),
                      TitleLargeLabel(
                        AppLocalizations.of(context)!.dropFoldersHere,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Handle dropped files/folders
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    final paths = details.files.map((file) => file.path).toList();

    // Use batch operation for better performance and data safety
    // This validates all repos in parallel and writes to YAML only once
    final results = await ref.read(workspaceProvider.notifier).addRepositoriesBatch(paths);

    // Count results
    int addedCount = results.where((r) => r.success).length;
    int invalidCount = results.where((r) => !r.success && !r.isDuplicate).length;
    int duplicateCount = results.where((r) => r.isDuplicate).length;

    // Add all successful repositories to the currently selected project in a single operation
    final selectedProject = ref.read(selectedProjectProvider);
    if (selectedProject != null && addedCount > 0) {
      final successfulPaths = results
          .where((r) => r.success && r.repository != null)
          .map((r) => r.repository!.path)
          .toList();

      if (successfulPaths.isNotEmpty) {
        try {
          await ref.read(projectProvider.notifier).addRepositoriesToWorkspaceBatch(
            selectedProject.id,
            successfulPaths,
          );
        } catch (e) {
          // If project add fails, show error but repositories are still in workspace
          if (mounted) {
            NotificationService.showError(
              context,
              'Added to workspace but failed to add to project: $e',
            );
          }
        }
      }
    }

    // Trigger status analysis for all repositories (including newly added ones)
    // GUARD: Only trigger if config has finished loading
    final configLoading = ref.read(configLoadingProvider);
    if (addedCount > 0 && !configLoading) {
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
    }

    // Show feedback with detailed error messages
    if (mounted) {
      String message;
      Color? backgroundColor;

      if (addedCount > 0) {
        message = 'Added $addedCount ${addedCount == 1 ? 'repository' : 'repositories'}';
        if (duplicateCount > 0) {
          message += ' ($duplicateCount already existed)';
        }
        if (invalidCount > 0) {
          message += ' ($invalidCount invalid)';
        }
        backgroundColor = AppTheme.gitAdded;
      } else if (duplicateCount > 0) {
        message = '$duplicateCount ${duplicateCount == 1 ? 'repository' : 'repositories'} already in workspace';
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      } else {
        message = 'No valid Git repositories found';
        backgroundColor = Theme.of(context).colorScheme.error;
      }

      // Show appropriate notification based on result
      if (backgroundColor == Theme.of(context).colorScheme.error) {
        NotificationService.showError(context, message);
      }
    }
  }

  Widget _buildRepositoryGrid(
    BuildContext context,
    WidgetRef ref,
    List<WorkspaceRepository> repositories,
  ) {
    final currentRepoPath = ref.watch(currentRepositoryPathProvider);
    final selectedPaths = ref.watch(repositoryMultiSelectProvider);

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.2,
        crossAxisSpacing: AppTheme.paddingM,
        mainAxisSpacing: AppTheme.paddingM,
      ),
      itemCount: repositories.length,
      itemBuilder: (context, index) {
        final repo = repositories[index];
        final isSelected = currentRepoPath != null && repo.path == currentRepoPath;
        final isMultiSelected = selectedPaths.contains(repo.path);

        return RepositoryCard(
          repository: repo,
          isSelected: isSelected,
          isMultiSelected: isMultiSelected,
          showCheckbox: true, // Always show checkbox for easy multi-select
          onToggleSelection: () {
            ref.read(repositoryMultiSelectProvider.notifier).toggleSelection(repo);
          },
          onTap: () {
            // If multi-select mode is active, toggle selection
            if (selectedPaths.isNotEmpty) {
              ref.read(repositoryMultiSelectProvider.notifier).toggleSelection(repo);
            } else {
              _switchToRepository(context, ref, repo);
            }
          },
          onRemove: () => _confirmRemoveRepository(context, ref, repo),
          onToggleFavorite: () => _toggleFavorite(ref, repo),
          onEditRemoteUrl: () => _editRemoteUrl(context, ref, repo),
          onRenameRemote: () => _renameRemote(context, ref, repo),
          onPruneRemote: () => _pruneRemote(context, ref, repo),
        );
      },
    );
  }

  Widget _buildRepositoryList(
    BuildContext context,
    WidgetRef ref,
    List<WorkspaceRepository> repositories,
  ) {
    final currentRepoPath = ref.watch(currentRepositoryPathProvider);
    final selectedPaths = ref.watch(repositoryMultiSelectProvider);

    return ListView.builder(
      itemCount: repositories.length,
      itemBuilder: (context, index) {
        final repo = repositories[index];
        final isSelected = currentRepoPath != null && repo.path == currentRepoPath;
        final isMultiSelected = selectedPaths.contains(repo.path);

        return RepositoryListItem(
          repository: repo,
          isSelected: isSelected,
          isMultiSelected: isMultiSelected,
          showCheckbox: true, // Always show checkbox for easy multi-select
          onToggleSelection: () {
            ref.read(repositoryMultiSelectProvider.notifier).toggleSelection(repo);
          },
          onTap: () {
            // If multi-select mode is active, toggle selection
            if (selectedPaths.isNotEmpty) {
              ref.read(repositoryMultiSelectProvider.notifier).toggleSelection(repo);
            } else {
              _switchToRepository(context, ref, repo);
            }
          },
          onRemove: () => _confirmRemoveRepository(context, ref, repo),
          onToggleFavorite: () => _toggleFavorite(ref, repo),
          onEditRemoteUrl: () => _editRemoteUrl(context, ref, repo),
          onRenameRemote: () => _renameRemote(context, ref, repo),
          onPruneRemote: () => _pruneRemote(context, ref, repo),
        );
      },
    );
  }

  Future<void> _openRepository(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      if (context.mounted) {
        await BaseDialog.show(
          context: context,
          dialog: BaseDialog(
            title: AppLocalizations.of(context)!.webBrowserLimitation,
            icon: PhosphorIconsRegular.globe,
            content: BodyMediumLabel(AppLocalizations.of(context)!.dialogContentWebBrowserLimitationRepositories),
            actions: [
              BaseButton(
                label: AppLocalizations.of(context)!.ok,
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Git Repository',
    );

    if (result != null && context.mounted) {
      // Add to workspace
      final added = await ref.read(workspaceProvider.notifier).addRepository(result);

      if (added) {
        // Add to currently selected project
        final selectedProject = ref.read(selectedProjectProvider);
        if (selectedProject != null) {
          await ref.read(projectProvider.notifier).addRepositoryToWorkspace(
            selectedProject.id,
            result.replaceAll('\\', '/'),
          );
        }

        // Trigger status analysis for the newly added repository
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      } else {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Not a valid Git repository or already exists');
      }
    }
  }

  Future<void> _switchToRepository(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repo,
  ) async {
    if (!repo.isValidGitRepo) {
      if (context.mounted) {
        NotificationService.showError(context, 'Repository is invalid or missing');
      }
      return;
    }

    // Update last accessed
    await ref.read(workspaceProvider.notifier).markAccessed(repo.path);

    // Open in git service (this will set as current repository)
    await ref.read(gitActionsProvider).openRepository(repo.path);
  }

  Future<void> _confirmRemoveRepository(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repo,
  ) async {
    final confirmed = await BaseDialog.show<bool>(
      context: context,
      dialog: BaseDialog(
        title: AppLocalizations.of(context)!.removeRepository,
        icon: PhosphorIconsRegular.trash,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(
          'Remove "${repo.displayName}" from workspace?\n\n'
          'This will not delete any files.',
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.remove,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Remove repository from workspace
      await ref.read(workspaceProvider.notifier).removeRepository(repo.path);

      // Remove repository path from all projects that contain it
      final projects = ref.read(projectProvider);
      for (final project in projects) {
        if (project.containsRepository(repo.path)) {
          await ref.read(projectProvider.notifier).removeRepositoryFromWorkspace(project.id, repo.path);
        }
      }

    }
  }

  Future<void> _toggleFavorite(WidgetRef ref, WorkspaceRepository repo) async {
    await ref.read(workspaceProvider.notifier).updateRepository(
          repo.path,
          isFavorite: !repo.isFavorite,
        );
  }

  Future<void> _validateRepositories(WidgetRef ref) async {
    Logger.info('Dashboard: Validate All clicked - running full repository analysis');

    // Get count before validation
    final totalRepos = ref.read(workspaceProvider).length;
    Logger.info('Dashboard: Starting full validation of $totalRepos repositories');

    // Run FULL repository analysis (like on startup)
    Logger.info('Running full repository status analysis...');
    await ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

    // Now validate and remove any that failed analysis
    Logger.info('Checking for invalid repositories after analysis...');
    await ref.read(workspaceProvider.notifier).validateRepositories();

    // Get count after validation
    final remainingRepos = ref.read(workspaceProvider).length;
    final removedCount = totalRepos - remainingRepos;
    Logger.info('Dashboard: Validation complete. Removed: $removedCount, Remaining: $remainingRepos');

    // Show feedback to user with proper colors
    if (!mounted) return;

    if (removedCount > 0) {
      // Warning: repositories were removed
      NotificationService.showWarning(
        context,
        'Removed $removedCount invalid ${removedCount == 1 ? 'repository' : 'repositories'}',
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await BaseDialog.show<bool>(
      context: context,
      dialog: BaseDialog(
        title: AppLocalizations.of(context)!.clearAllRepositories,
        icon: PhosphorIconsRegular.warning,
        variant: DialogVariant.destructive,
        content: const BodyMediumLabel(
          'Remove all repositories from workspace?\n\n'
          'This will not delete any files.',
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.clearAll,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Get all repository paths before clearing
      final repoPaths = ref.read(workspaceProvider).map((repo) => repo.path).toList();

      // Clear all repositories from workspace
      await ref.read(workspaceProvider.notifier).clearAll();

      // Remove all repository paths from all projects
      final projects = ref.read(projectProvider);
      for (final project in projects) {
        for (final path in repoPaths) {
          if (project.containsRepository(path)) {
            await ref.read(projectProvider.notifier).removeRepositoryFromWorkspace(project.id, path);
          }
        }
      }
    }
  }

  Future<void> _showCloneDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const CloneRepositoryDialog(),
    );
  }

  Future<void> _showInitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const InitializeRepositoryDialog(),
    );
  }

  // ============================================
  // Batch Operations
  // ============================================

  /// Edit remote URL for a repository
  Future<void> _editRemoteUrl(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repository,
  ) async {
    // Get git service
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final gitService = GitService(repository.path, gitExecutablePath: gitExecutablePath);

    try {
      // Fetch origin remote
      final remotes = await gitService.getRemotes();
      final originRemote = remotes.firstWhere(
        (remote) => remote.name == 'origin',
        orElse: () => throw Exception('No origin remote found'),
      );

      if (!context.mounted) return;

      // Show edit dialog
      final newUrl = await showDialog<String>(
        context: context,
        builder: (context) => EditRemoteUrlDialog(remote: originRemote),
      );

      if (newUrl == null || !context.mounted) return;

      // Update remote URL
      await gitService.setRemoteUrl('origin', newUrl);

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          'Remote URL updated successfully',
        );
        // Refresh repository status
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to edit remote URL: $e',
        );
      }
    }
  }

  /// Rename remote for a repository
  Future<void> _renameRemote(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repository,
  ) async {
    // Get git service
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final gitService = GitService(repository.path, gitExecutablePath: gitExecutablePath);

    try {
      // Fetch origin remote
      final remotes = await gitService.getRemotes();
      final originRemote = remotes.firstWhere(
        (remote) => remote.name == 'origin',
        orElse: () => throw Exception('No origin remote found'),
      );

      if (!context.mounted) return;

      // Show rename dialog
      final newName = await showDialog<String>(
        context: context,
        builder: (context) => RenameRemoteDialog(remote: originRemote),
      );

      if (newName == null || !context.mounted) return;

      // Rename remote
      await gitService.renameRemote('origin', newName);

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          'Remote renamed successfully',
        );
        // Refresh repository status
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to rename remote: $e',
        );
      }
    }
  }

  /// Prune remote for a repository
  Future<void> _pruneRemote(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repository,
  ) async {
    // Get git service
    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final gitService = GitService(repository.path, gitExecutablePath: gitExecutablePath);

    try {
      // Fetch origin remote
      final remotes = await gitService.getRemotes();
      final originRemote = remotes.firstWhere(
        (remote) => remote.name == 'origin',
        orElse: () => throw Exception('No origin remote found'),
      );

      if (!context.mounted) return;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => PruneRemoteDialog(remote: originRemote),
      );

      if (confirmed != true || !context.mounted) return;

      // Prune remote
      await gitService.fetch(remote: 'origin', prune: true);

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          'Remote pruned successfully',
        );
        // Refresh repository status
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to prune remote: $e',
        );
      }
    }
  }
}