import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ChoiceGroupSpec,
        ChoiceOption,
        ContentPort,
        DialogRouteSpec,
        DropTargetSpec,
        GridDensity,
        IconRole,
        Inset,
        MenuAction,
        MenuActionRole,
        MenuSeparator,
        Overlays,
        Proximity,
        ScreenSpec,
        Skin,
        SkinScope,
        TextRole,
        ToolbarChoiceEntry,
        ToolbarEntry,
        ToolbarGroup,
        ToolbarMenuEntry;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/screen_body_host.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_dialog.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/git_service.dart';
import '../../core/config/config_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/models/workspace.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../../core/workspace/models/repository_status.dart';
import '../../core/workspace/repository_status_provider.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/editor_launcher_service.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/utils/result_extensions.dart';
import '../../shared/dialogs/clone_repository_dialog.dart';
import '../../shared/dialogs/initialize_repository_dialog.dart';
import '../../shared/dialogs/edit_remote_url_dialog.dart';
import '../../core/services/notification_service.dart';
import 'widgets/repository_card.dart';
import 'widgets/repository_list_item.dart';
import 'widgets/repositories_filter_chips.dart';
import 'widgets/repositories_empty_state.dart';
import 'repository_multi_select_provider.dart';
import '../../shared/components/base_layout.dart';

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

  late final ItemNavigationController _navigationController;

  /// The repositories currently shown (project- and chip-filtered), in
  /// collection order, so the keyboard activation resolves an index against
  /// exactly what the user sees. Grid and list render the same order, so one
  /// controller serves both view modes.
  List<WorkspaceRepository> _visibleRepositories = const [];

  // Filter states
  bool _filterCleanOnly = false;
  bool _filterWithRemote = false;

  @override
  void initState() {
    super.initState();
    // Initial trigger will happen in build after repositories are loaded
    _navigationController = ItemNavigationController(
      onActivate: _activateRepositoryAt,
    );
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  /// The keyboard activation of a repository, mirroring what a click does:
  /// with a multi-selection running it toggles membership, otherwise it
  /// opens the repository.
  void _activateRepositoryAt(int index) {
    if (index < 0 || index >= _visibleRepositories.length) return;
    final repo = _visibleRepositories[index];
    if (ref.read(repositoryMultiSelectProvider).isNotEmpty) {
      ref.read(repositoryMultiSelectProvider.notifier).toggleSelection(repo);
    } else {
      _switchToRepository(context, ref, repo);
    }
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
            if (selectedProject.id == Workspace.defaultId) {
              // Check if this repo is assigned to any other project
              final projects = ref.read(projectProvider);
              final isAssignedToOther = projects
                  .where((p) => p.id != Workspace.defaultId)
                  .any((p) => p.containsRepository(repo.path));

              // Show if not assigned to other projects OR explicitly assigned to default
              final shouldShow =
                  !isAssignedToOther ||
                  selectedProject.containsRepository(repo.path);

              if (kDebugMode) {
                Logger.debug(
                  '[Default Project] Repo "${repo.path}" - assigned to other: $isAssignedToOther, in default: ${selectedProject.containsRepository(repo.path)}, showing: $shouldShow',
                );
              }
              return shouldShow;
            }

            // For non-default projects, only show explicitly assigned repos
            final contains = selectedProject.containsRepository(repo.path);
            if (kDebugMode) {
              Logger.debug(
                'Filtering repo "${repo.path}" for project "${selectedProject.name}": $contains',
              );
            }
            return contains;
          }).toList()
        : allRepositories;

    final hasRepositories = repositories.isNotEmpty;

    // Apply filters
    final filteredRepositories = _applyFilters(repositories, statuses);
    final selectedRepositories = repositories
        .where((r) => selectedPaths.contains(r.path))
        .toList();

    _visibleRepositories = filteredRepositories;
    if (filteredRepositories.isNotEmpty) {
      _navigationController.scheduleInitialHighlight();
    }

    // Assign unassigned repositories to default project on first load
    if (!_hasAssignedRepos &&
        allRepositories.isNotEmpty &&
        selectedProject != null) {
      _hasAssignedRepos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final allRepoPaths = allRepositories.map((r) => r.path).toList();
        await ref
            .read(projectProvider.notifier)
            .assignUnassignedRepositories(allRepoPaths, selectedProject.id);
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

    // The drag overlay is the SKIN's, through `surfaces.dropTarget`. What this
    // screen states is the two facts it owns - something is over the window
    // right now, and what this region accepts - and everything the overlay was
    // hand-painting is the member's: the wash over the screen, the callout, its
    // fill, its 2 px accent edge, its corner, the mark and the sentence. The
    // Stack and the `if (_isDragging)` branch go with it, because the member
    // already stacks its overlay over the child it is given.
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleDroppedFiles(details),
      child: SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.dropTarget(
          inner,
          DropTargetSpec(
            active: _isDragging,
            icon: IconRole.folderOpen,
            label: AppLocalizations.of(context)!.dropFoldersHere,
            child: ContentPort(
              // The frame inside the drop target is `chrome.screen`'s (#442).
              // The view switch travels as a `ToolbarChoiceEntry` rather than
              // as the raw `SegmentedButton` this file used to hand to
              // `StandardAppBar.additionalActions`; see the same conversion on
              // the workspaces screen for what changes on screen, named there
              // in full (the segments gain the tooltip an icon-only control
              // owes, the segment box becomes the skin's metric rather than
              // this file's 18 pixels, and the switch-to-anchor gap becomes
              // the bar's uniform 8 where this file stated 16).
              skin.chrome.screen(
                inner,
                ScreenSpec(
                  title: AppDestination.repositories.label(context),
                  toolbar: <ToolbarGroup>[
                    ToolbarGroup(<ToolbarEntry>[
                      if (hasRepositories)
                        ToolbarChoiceEntry<RepositoriesViewMode>(
                          ChoiceGroupSpec<RepositoriesViewMode>(
                            label: AppLocalizations.of(context)!.viewOptions,
                            selected: ref.watch(repositoriesViewModeProvider),
                            onSelected: (RepositoriesViewMode mode) => ref
                                .read(configProvider.notifier)
                                .setRepositoriesViewMode(mode),
                            options: <ChoiceOption<RepositoriesViewMode>>[
                              ChoiceOption<RepositoriesViewMode>(
                                value: RepositoriesViewMode.grid,
                                label: AppLocalizations.of(
                                  context,
                                )!.viewModeGrid,
                                icon: IconRole.gridFour,
                              ),
                              ChoiceOption<RepositoriesViewMode>(
                                value: RepositoriesViewMode.list,
                                label: AppLocalizations.of(
                                  context,
                                )!.viewModeList,
                                icon: IconRole.listBullets,
                              ),
                            ],
                          ),
                        ),
                      ToolbarMenuEntry(
                        icon: IconRole.dotsThreeVertical,
                        tooltip: AppLocalizations.of(context)!.moreActions,
                        entries: [
                          // Add repository action (first). The mark's scale is gone
                          // with the widget rows: a menu entry's mark is drawn at the
                          // size the SKIN's menu rows use, and `ControlScale.normal`
                          // here was this screen setting a menu's own metric. Named
                          // rather than silent: this SHRINKS the marks in this menu
                          // (and the settings overflow's, the repository card's and the
                          // repository list row's - the four surfaces that passed
                          // `normal`) from 20 to the 16 every other menu already used;
                          // the skin's one answer replaces the two the screens gave.
                          MenuAction(
                            icon: IconRole.plus,
                            label: AppLocalizations.of(
                              context,
                            )!.tooltipAddRepository,
                            onPressed: () => _openRepository(context, ref),
                          ),
                          const MenuSeparator(),
                          // Clone action
                          MenuAction(
                            icon: IconRole.downloadSimple,
                            label: AppLocalizations.of(
                              context,
                            )!.cloneRepository,
                            onPressed: () => _showCloneDialog(context),
                          ),
                          // Initialize action
                          MenuAction(
                            icon: IconRole.folderPlus,
                            label: AppLocalizations.of(
                              context,
                            )!.initializeRepository,
                            onPressed: () => _showInitDialog(context),
                          ),
                          const MenuSeparator(),
                          // Validate action
                          MenuAction(
                            icon: IconRole.checkCircle,
                            label: AppLocalizations.of(context)!.validateAll,
                            onPressed: () => _validateRepositories(ref),
                          ),
                          // Remove all from workspace (conditional). It says what it
                          // MEANS - this entry destroys something - and the skin
                          // decides how a destructive row reads.
                          if (hasRepositories)
                            MenuAction(
                              icon: IconRole.trash,
                              label: AppLocalizations.of(
                                context,
                              )!.clearAllRepositories,
                              role: MenuActionRole.destructive,
                              onPressed: () => _confirmClearAll(context, ref),
                            ),
                        ],
                      ),
                    ]),
                  ],
                  body: ContentPort(
                    ScreenBodyHost(
                      child: BaseInset(
                        all: Inset.roomy,
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
                              const BaseGap(Proximity.grouped),
                            ],

                            // Content
                            Expanded(
                              child: hasRepositories
                                  ? Consumer(
                                      builder: (context, ref, child) {
                                        final viewMode = ref.watch(
                                          repositoriesViewModeProvider,
                                        );
                                        return viewMode ==
                                                RepositoriesViewMode.grid
                                            ? _buildRepositoryGrid(
                                                context,
                                                ref,
                                                filteredRepositories,
                                              )
                                            : _buildRepositoryList(
                                                context,
                                                ref,
                                                filteredRepositories,
                                              );
                                      },
                                    )
                                  : RepositoriesEmptyState(
                                      onOpenRepository: () =>
                                          _openRepository(context, ref),
                                      onCloneRepository: () =>
                                          _showCloneDialog(context),
                                      onInitRepository: () =>
                                          _showInitDialog(context),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Handle dropped files/folders
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    final paths = details.files.map((file) => file.path).toList();

    // Use batch operation for better performance and data safety
    // This validates all repos in parallel and writes to YAML only once
    final results = await ref
        .read(workspaceProvider.notifier)
        .addRepositoriesBatch(paths);
    if (!mounted) return;

    // Count results
    int addedCount = results.where((r) => r.success).length;
    int invalidCount = results
        .where((r) => !r.success && !r.isDuplicate)
        .length;
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
          await ref
              .read(projectProvider.notifier)
              .addRepositoriesToWorkspaceBatch(
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

    if (!mounted) return;

    // Trigger status analysis for all repositories (including newly added ones)
    // GUARD: Only trigger if config has finished loading
    final configLoading = ref.read(configLoadingProvider);
    if (addedCount > 0 && !configLoading) {
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
    }

    // Show feedback with detailed error messages
    if (mounted) {
      if (addedCount > 0) {
        String message =
            'Added $addedCount ${addedCount == 1 ? 'repository' : 'repositories'}';
        if (duplicateCount > 0) {
          message += ' ($duplicateCount already existed)';
        }
        if (invalidCount > 0) {
          message += ' ($invalidCount invalid)';
        }
        NotificationService.showSuccess(context, message);
      } else if (duplicateCount > 0) {
        NotificationService.showInfo(
          context,
          '$duplicateCount ${duplicateCount == 1 ? 'repository' : 'repositories'} already in workspace',
        );
      } else {
        NotificationService.showError(
          context,
          'No valid Git repositories found',
        );
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

    // The grid's geometry is `layout.grid`'s: the screen states how tightly
    // packed the cards should sit and the member answers with the tile
    // extent, the aspect ratio, the gutters AND the resolved column count the
    // keyboard controller needs. `roomy` is the rung that carries the 400
    // pixels these cards were laid out at.
    return KeyboardNavigableGridView(
      controller: _navigationController,
      itemCount: repositories.length,
      autofocus: true,
      density: GridDensity.roomy,
      itemBuilder: (context, index, isHighlighted, containerHasFocus) {
        final repo = repositories[index];
        final isSelected =
            currentRepoPath != null && repo.path == currentRepoPath;
        final isMultiSelected = selectedPaths.contains(repo.path);

        return RepositoryCard(
          repository: repo,
          isSelected: isSelected,
          isMultiSelected: isMultiSelected,
          isHighlighted: isHighlighted,
          containerHasFocus: containerHasFocus,
          showCheckbox: true, // Always show checkbox for easy multi-select
          onToggleSelection: () {
            ref
                .read(repositoryMultiSelectProvider.notifier)
                .toggleSelection(repo);
          },
          onTap: () {
            // A click moves the highlight to the card it acted on, so
            // keyboard and mouse stay in one story.
            _navigationController.select(index);
            _activateRepositoryAt(index);
          },
          onRemove: () => _confirmRemoveRepository(context, ref, repo),
          onToggleFavorite: () => _toggleFavorite(ref, repo),
          onOpenInEditor: () => _openInEditor(context, ref, repo),
          onEditRemoteUrl: () => _editRemoteUrl(context, ref, repo),
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

    _navigationController.crossAxisCount = 1;

    return KeyboardNavigableListView(
      controller: _navigationController,
      itemCount: repositories.length,
      autofocus: true,
      itemBuilder: (context, index, isHighlighted, containerHasFocus) {
        final repo = repositories[index];
        final isSelected =
            currentRepoPath != null && repo.path == currentRepoPath;
        final isMultiSelected = selectedPaths.contains(repo.path);

        return RepositoryListItem(
          repository: repo,
          isSelected: isSelected,
          isMultiSelected: isMultiSelected,
          isHighlighted: isHighlighted,
          containerHasFocus: containerHasFocus,
          showCheckbox: true, // Always show checkbox for easy multi-select
          onToggleSelection: () {
            ref
                .read(repositoryMultiSelectProvider.notifier)
                .toggleSelection(repo);
          },
          onTap: () {
            // A click moves the highlight to the row it acted on, so
            // keyboard and mouse stay in one story.
            _navigationController.select(index);
            _activateRepositoryAt(index);
          },
          onRemove: () => _confirmRemoveRepository(context, ref, repo),
          onToggleFavorite: () => _toggleFavorite(ref, repo),
          onOpenInEditor: () => _openInEditor(context, ref, repo),
          onEditRemoteUrl: () => _editRemoteUrl(context, ref, repo),
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
            icon: IconRole.globe,
            onSubmit: () => Navigator.of(context).pop(),
            content: BaseLabel(
              AppLocalizations.of(
                context,
              )!.dialogContentWebBrowserLimitationRepositories,
              role: TextRole.body,
            ),
            actions: [
              DialogAction(
                label: AppLocalizations.of(context)!.ok,
                role: DialogActionRole.affirmative,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      return;
    }

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Git Repository',
    );

    if (result != null && context.mounted) {
      // Add to workspace
      final added = await ref
          .read(workspaceProvider.notifier)
          .addRepository(result);
      if (!context.mounted) return;

      if (added) {
        // Add to currently selected project
        final selectedProject = ref.read(selectedProjectProvider);
        if (selectedProject != null) {
          await ref
              .read(projectProvider.notifier)
              .addRepositoryToWorkspace(
                selectedProject.id,
                result.replaceAll('\\', '/'),
              );
          if (!context.mounted) return;
        }

        // Trigger status analysis for the newly added repository
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      } else {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Not a valid Git repository or already exists',
        );
      }
    }
  }

  Future<void> _switchToRepository(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repo,
  ) async {
    if (!repo.isValidGitRepo) {
      context.showErrorIfMounted('Repository is invalid or missing');
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
        icon: IconRole.trash,
        variant: DialogVariant.destructive,
        content: BaseLabel(
          'Remove "${repo.displayName}" from workspace?\n\n'
          'This will not delete any files.',
          role: TextRole.body,
        ),
        actions: [
          DialogAction(
            label: AppLocalizations.of(context)!.cancel,
            role: DialogActionRole.dismissive,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogAction(
            label: AppLocalizations.of(context)!.remove,
            role: DialogActionRole.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Remove repository from workspace
      await ref.read(workspaceProvider.notifier).removeRepository(repo.path);
      if (!context.mounted) return;

      // A removed repository must not stay selected, otherwise multi-select mode
      // stays active with nothing visible selected
      ref.read(repositoryMultiSelectProvider.notifier).deselect(repo);

      // Remove repository path from all projects that contain it
      final projects = ref.read(projectProvider);
      for (final project in projects) {
        if (project.containsRepository(repo.path)) {
          await ref
              .read(projectProvider.notifier)
              .removeRepositoryFromWorkspace(project.id, repo.path);
          if (!context.mounted) return;
        }
      }
    }
  }

  Future<void> _toggleFavorite(WidgetRef ref, WorkspaceRepository repo) async {
    await ref
        .read(workspaceProvider.notifier)
        .updateRepository(repo.path, isFavorite: !repo.isFavorite);
  }

  Future<void> _validateRepositories(WidgetRef ref) async {
    Logger.info(
      'Dashboard: Validate All clicked - running full repository analysis',
    );

    // Get count before validation
    final totalRepos = ref.read(workspaceProvider).length;
    Logger.info(
      'Dashboard: Starting full validation of $totalRepos repositories',
    );

    // Run FULL repository analysis (like on startup)
    Logger.info('Running full repository status analysis...');
    await ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
    if (!mounted) return;

    // Now validate and remove any that failed analysis
    Logger.info('Checking for invalid repositories after analysis...');
    await ref.read(workspaceProvider.notifier).validateRepositories();
    if (!mounted) return;

    // Get count after validation
    final remainingRepos = ref.read(workspaceProvider).length;
    final removedCount = totalRepos - remainingRepos;

    // Repositories dropped by validation must not stay selected
    ref
        .read(repositoryMultiSelectProvider.notifier)
        .retainPaths(
          ref.read(workspaceProvider).map((repo) => repo.path).toSet(),
        );
    Logger.info(
      'Dashboard: Validation complete. Removed: $removedCount, Remaining: $remainingRepos',
    );

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
        icon: IconRole.warning,
        variant: DialogVariant.destructive,
        content: const BaseLabel(
          'Remove all repositories from workspace?\n\n'
          'This will not delete any files.',
          role: TextRole.body,
        ),
        actions: [
          DialogAction(
            label: AppLocalizations.of(context)!.cancel,
            role: DialogActionRole.dismissive,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogAction(
            label: AppLocalizations.of(context)!.clearAll,
            role: DialogActionRole.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Get all repository paths before clearing
      final repoPaths = ref
          .read(workspaceProvider)
          .map((repo) => repo.path)
          .toList();

      // Clear all repositories from workspace
      await ref.read(workspaceProvider.notifier).clearAll();
      if (!context.mounted) return;

      // No repository is left to be selected
      ref.read(repositoryMultiSelectProvider.notifier).clearSelection();

      // Remove all repository paths from all projects
      final projects = ref.read(projectProvider);
      for (final project in projects) {
        for (final path in repoPaths) {
          if (project.containsRepository(path)) {
            await ref
                .read(projectProvider.notifier)
                .removeRepositoryFromWorkspace(project.id, path);
            if (!context.mounted) return;
          }
        }
      }
    }
  }

  Future<void> _showCloneDialog(BuildContext context) async {
    await Overlays.dialogFrom(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.cloneRepository,
      ),
      builder: (context) => const CloneRepositoryDialog(),
    );
  }

  Future<void> _showInitDialog(BuildContext context) async {
    await Overlays.dialogFrom(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.initializeRepository,
      ),
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
    final gitService = GitService(
      repository.path,
      gitExecutablePath: gitExecutablePath,
    );

    // Fetch origin remote
    final remotesResult = await gitService.getRemotes();
    if (!context.mounted) return;
    final remotes = remotesResult.unwrapOrNotifyNull(
      context,
      errorPrefix: 'Failed to fetch remotes',
    );
    if (remotes == null) return;
    // The menu entry is offered for any remote, not just 'origin', so fall back
    // to the first remote instead of failing on the conventional name.
    final origin = remotes
        .where((remote) => remote.name == 'origin')
        .firstOrNull;
    final originRemote = origin ?? remotes.firstOrNull;
    if (originRemote == null) {
      NotificationService.showError(context, 'No remote found');
      return;
    }

    if (!context.mounted) return;

    // Show edit dialog
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => EditRemoteUrlDialog(remote: originRemote),
    );

    if (newUrl == null || !context.mounted) return;

    // Update remote URL
    final result = await gitService.setRemoteUrl(originRemote.name, newUrl);
    if (!context.mounted) return;
    result.executeWithNotification(
      context,
      successMessage: 'Remote URL updated successfully',
      errorPrefix: 'Failed to edit remote URL',
      onSuccess: () {
        // Refresh repository status
        ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();
      },
    );
  }

  /// Open repository folder in text editor
  Future<void> _openInEditor(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRepository repository,
  ) async {
    final editor = ref.read(preferredTextEditorProvider);
    if (editor == null || editor.isEmpty) {
      Logger.warning('No text editor configured in settings');
      context.showErrorIfMounted(
        'No text editor configured. Please set a text editor in Settings.',
      );
      return;
    }

    try {
      Logger.info(
        'Opening folder in editor: ${repository.path} with editor: $editor',
      );
      await EditorLauncherService.launch(
        editorPath: editor,
        targetPath: repository.path,
      );
    } catch (e) {
      Logger.error(
        'Error opening editor: $editor with folder: ${repository.path}',
        e,
      );
      if (context.mounted) {
        context.showErrorIfMounted(
          'Failed to open editor: $editor\nFolder: ${repository.path}\nError: $e',
        );
      }
    }
  }
}
