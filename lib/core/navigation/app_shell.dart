import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/command_log_panel.dart';
import '../../shared/widgets/workspace_switcher.dart';
import '../../shared/widgets/repository_switcher.dart';
import '../../shared/widgets/branch_switcher.dart';
import '../../shared/widgets/quick_settings_menu.dart';
import '../../features/repositories/widgets/global_branch_switcher.dart';
import '../../shared/widgets/language_selector.dart';
import '../../shared/widgets/progress_overlay.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_badge.dart';
import '../git/git_command_log_provider.dart';
import '../git/git_providers.dart';
import '../config/config_providers.dart' hide commandLogPanelVisibleProvider;
import '../services/notification_service.dart';
import '../../shared/dialogs/repository_switcher_dialog.dart';
import '../workspace/repository_status_provider.dart';
import '../workspace/workspace_repository_watchers_provider.dart';
import '../workspace/workspace_provider.dart';
import '../workspace/models/repository_status.dart';
import '../workspace/models/workspace_repository.dart';
import 'navigation_item.dart';
import '../../features/repositories/repository_multi_select_provider.dart';
import '../../features/repositories/repository_batch_error_provider.dart';
import '../../features/repositories/services/batch_operations_service.dart';
import '../../features/repositories/dialogs/batch_operation_progress_dialog.dart';
import '../../features/repositories/dialogs/create_branch_dialog.dart';
import '../../features/repositories/dialogs/create_pull_request_dialog.dart';
import '../../shared/dialogs/merge_branches_dialog.dart';
import '../git/git_service.dart';
import '../git/git_platform_service.dart';
import '../git/models/branch.dart';
import 'command_palette.dart';
import '../../features/workspaces/workspaces_screen.dart';
import '../../features/repositories/repositories_screen.dart';
import '../../features/changes/changes_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/branches/branches_screen.dart';
import '../../features/stashes/stashes_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/changelog/changelog_dialog.dart';
import '../../shared/dialogs/update_available_dialog.dart';
import '../services/update_providers.dart';
import '../../features/about/about_dialog.dart';

/// Provider to track if "What's New" dialog has been checked this session
/// This persists across widget rebuilds to prevent showing dialog multiple times
final whatsNewDialogCheckedProvider = StateProvider<bool>((ref) => false);

/// App shell with navigation rail and main content area
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _hasCheckedSettings = false;
  bool _hasShownConfigLoadWarning = false;
  bool _hasShownGitPathWarning = false;

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(navigationDestinationProvider);
    final configLoading = ref.watch(configLoadingProvider);
    final configLoadFailed = ref.watch(configLoadFailureProvider);
    final gitPathInvalid = ref.watch(gitPathInvalidProvider);
    final allSettingsConfigured = ref.watch(allRequiredSettingsConfiguredProvider);
    final missingSettings = ref.watch(missingRequiredSettingsProvider(context));
    final isRailExtended = ref.watch(navigationRailExtendedProvider);
    final whatsNewChecked = ref.watch(whatsNewDialogCheckedProvider);

    // IMPORTANT: Initialize workspaceRepositoryStatusProvider EARLY
    // This ensures the listener is set up BEFORE config finishes loading
    // so it can catch the config loading state change and trigger refreshAll()
    ref.watch(workspaceRepositoryStatusProvider);

    // IMPORTANT: Only enable repository watcher AFTER config is fully loaded
    // This prevents race condition where status checks start before git path is configured
    if (!configLoading) {
      // Enable global file system watcher for automatic updates across all views
      ref.watch(repositoryWatcherProvider);

      // Initialize workspace repository watchers for ALL repositories
      // This watches all repositories in the workspace and triggers validation on file changes
      ref.watch(workspaceRepositoryWatchersProvider);
    }

    // Auto-navigate to settings if required settings are missing
    // Only check after config has finished loading (only check once)
    if (!_hasCheckedSettings && !configLoading && !allSettingsConfigured) {
      _hasCheckedSettings = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (destination != AppDestination.settings) {
          ref.read(navigationDestinationProvider.notifier).state = AppDestination.settings;
        }
      });
    }

    // Show warning if config failed to load
    if (!_hasShownConfigLoadWarning && !configLoading && configLoadFailed) {
      _hasShownConfigLoadWarning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Configuration could not be loaded. Using default settings.',
          );
        }
      });
    }

    // Show warning if git path is invalid
    if (!_hasShownGitPathWarning && !configLoading && gitPathInvalid) {
      _hasShownGitPathWarning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Git executable path is invalid or git is not installed. Please configure git in Settings.',
          );
        }
      });
    }

    // Show "What's New" dialog on app upgrade
    // IMPORTANT: Only trigger the check ONCE per app session using global provider
    // This persists across widget rebuilds, preventing dialog from showing multiple times
    // The actual check of whether to show is done by VersionService.shouldShowWhatsNew()
    // NOTE: We don't require allSettingsConfigured here because users should see release
    // notes even if they haven't finished setting up the app yet
    if (!whatsNewChecked && !configLoading) {
      // Mark as checked and show dialog AFTER build phase to prevent state modification error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(whatsNewDialogCheckedProvider.notifier).state = true;
        ChangelogDialog.showIfNeeded(context, ref);
      });
    }

    // Show update available notification if new version is available
    // Only show once per session for each version
    final updateAvailable = ref.watch(updateAvailableProvider);
    final dialogShownVersion = ref.watch(updateDialogShownProvider);

    if (updateAvailable != null &&
        !configLoading &&
        allSettingsConfigured &&
        dialogShownVersion != updateAvailable.version) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          // Mark this version as shown for this session
          ref.read(updateDialogShownProvider.notifier).state = updateAvailable.version;

          showDialog(
            context: context,
            barrierDismissible: false, // Prevent dismissing by clicking outside
            builder: (context) => UpdateAvailableDialog(updateInfo: updateAvailable),
          );
        }
      });
    }

    // Get currently selected repository path
    final currentRepoPath = ref.watch(currentRepositoryPathProvider);

    // Get status of selected repository (if any)
    final selectedRepoStatus = currentRepoPath != null
        ? ref.watch(repositoryStatusByPathProvider(currentRepoPath))
        : null;

    return CallbackShortcuts(
      bindings: _buildShortcuts(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              Row(
                children: [
                  // Navigation Rail
                  NavigationRail(
                extended: isRailExtended,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                selectedIndex: destination.index,
                onDestinationSelected: (index) {
                  ref.read(navigationDestinationProvider.notifier).state =
                      AppDestination.values[index];
                },
                leading: Column(
                  children: [
                    const SizedBox(height: AppTheme.paddingM),
                    // App logo/title - double-tap to show About dialog
                    GestureDetector(
                      onDoubleTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const AppAboutDialog(),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(
                            PhosphorIconsBold.gitBranch,
                            size: AppTheme.iconXL,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          if (isRailExtended) ...[
                            const SizedBox(height: AppTheme.paddingS),
                            TitleMediumLabel(
                              AppLocalizations.of(context)!.appTitle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingL),
                  ],
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.paddingM),
                      child: BaseIconButton(
                        icon: isRailExtended
                            ? PhosphorIconsRegular.caretLeft
                            : PhosphorIconsRegular.caretRight,
                        onPressed: () {
                          ref.read(configProvider.notifier).setNavigationRailExtended(!isRailExtended);
                        },
                        tooltip: isRailExtended
                            ? AppLocalizations.of(context)!.collapse
                            : AppLocalizations.of(context)!.expand,
                      ),
                    ),
                  ),
                ),
                destinations: AppDestination.values.map((dest) {
                  // Show badges ONLY for selected repository
                  int? badgeCount;
                  if (selectedRepoStatus != null && !selectedRepoStatus.isLoading) {
                    // Only show badges when a repository is selected
                    if (dest == AppDestination.changes && selectedRepoStatus.hasUncommittedChanges) {
                      // Show actual count of changed files (staged + unstaged)
                      final allStatuses = ref.watch(repositoryStatusProvider).value ?? [];
                      badgeCount = allStatuses.length;
                      // Don't show badge if count is 0
                      if (badgeCount == 0) badgeCount = null;
                    } else if (dest == AppDestination.stashes) {
                      // Show stash count badge
                      badgeCount = ref.watch(stashCountProvider);
                      // Don't show badge if count is 0
                      if (badgeCount == 0) badgeCount = null;
                    }
                  }

                  return NavigationRailDestination(
                    icon: _buildIconWithBadge(context, Icon(dest.icon), badgeCount),
                    selectedIcon: _buildIconWithBadge(context, Icon(dest.iconSelected), badgeCount),
                    label: BodyMediumLabel(dest.label(context)),
                  );
                }).toList(),
              ),

              // Vertical divider
              const VerticalDivider(thickness: 1, width: 1),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Top bar with command log toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingM,
                        vertical: AppTheme.paddingS,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Workspace switcher
                          const WorkspaceSwitcher(),
                          const SizedBox(width: AppTheme.paddingM),
                          // Repository switcher
                          const RepositorySwitcher(),
                          const SizedBox(width: AppTheme.paddingM),
                          // Branch switcher
                          const BranchSwitcher(),
                          const SizedBox(width: AppTheme.paddingM),
                          // Global branch switcher
                          const GlobalBranchSwitcher(),
                          const SizedBox(width: AppTheme.paddingM),
                          // Create Branch and Create PR buttons
                          if (currentRepoPath != null) ...[
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.gitBranch,
                              AppLocalizations.of(context)!.createBranch,
                              () => _performCreateBranch(ref),
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.gitPullRequest,
                              AppLocalizations.of(context)!.createPr,
                              () => _performCreatePR(ref),
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.gitMerge,
                              AppLocalizations.of(context)!.mergeBranches,
                              () => _performMergeBranches(context),
                            ),
                            const SizedBox(width: AppTheme.paddingM),
                          ],
                          // Git operations (Fetch, Pull, Push)
                          if (currentRepoPath != null) ...[
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.arrowClockwise,
                              AppLocalizations.of(context)!.fetch,
                              () => _performFetch(ref),
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.arrowDown,
                              AppLocalizations.of(context)!.pull,
                              () => _performPull(ref),
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            _buildGitOperationButton(
                              context,
                              ref,
                              PhosphorIconsRegular.arrowUp,
                              AppLocalizations.of(context)!.push,
                              () => _performPush(ref),
                            ),
                          ],
                          const Spacer(),
                          BaseIconButton(
                            icon: PhosphorIconsRegular.magnifyingGlass,
                            tooltip: AppLocalizations.of(context)!.commandPaletteTooltip,
                            onPressed: () => _showCommandPalette(context),
                            size: ButtonSize.small,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          BaseIconButton(
                            icon: PhosphorIconsRegular.terminal,
                            tooltip: AppLocalizations.of(context)!.toggleCommandLogTooltip,
                            onPressed: () {
                              ref.read(commandLogPanelVisibleProvider.notifier).state =
                                  !ref.read(commandLogPanelVisibleProvider);
                            },
                            size: ButtonSize.small,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          // Quick settings menu
                          const QuickSettingsMenu(),
                          const SizedBox(width: AppTheme.paddingS),
                          // Language selector
                          const LanguageSelector(),
                        ],
                      ),
                    ),
                    // Warning banner for missing settings
                    if (!allSettingsConfigured)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.paddingM),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsBold.warning,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppTheme.paddingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TitleMediumLabel(
                                    'Required settings missing',
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(height: AppTheme.paddingXS),
                                  BodySmallLabel(
                                    'Please configure: ${missingSettings.join(', ')}',
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ],
                              ),
                            ),
                            if (destination != AppDestination.settings)
                              BaseButton(
                                label: AppLocalizations.of(context)!.goToSettings,
                                variant: ButtonVariant.danger,
                                onPressed: () {
                                  ref.read(navigationDestinationProvider.notifier).state =
                                      AppDestination.settings;
                                },
                              ),
                          ],
                        ),
                      ),
                    // Content
                    Expanded(
                      child: _buildContent(destination),
                    ),
                  ],
                ),
              ),

              // Command Log Panel
              const CommandLogPanel(),
                ],
              ),

              // Global progress overlay
              const ProgressOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build keyboard shortcuts
  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    return {
      // Command Palette
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
        _showCommandPalette(context);
      },

      // Toggle Command Log
      const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
        ref.read(commandLogPanelVisibleProvider.notifier).state =
            !ref.read(commandLogPanelVisibleProvider);
      },

      // Repository Switcher
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
        _showRepositorySwitcher(context);
      },

      // Navigation shortcuts
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
        _navigateTo(AppDestination.workspaces);
      },
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
        _navigateTo(AppDestination.repositories);
      },
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
        _navigateTo(AppDestination.changes);
      },
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
        _navigateTo(AppDestination.history);
      },
      const SingleActivator(LogicalKeyboardKey.digit5, control: true): () {
        _navigateTo(AppDestination.browse);
      },
      const SingleActivator(LogicalKeyboardKey.digit6, control: true): () {
        _navigateTo(AppDestination.branches);
      },
      const SingleActivator(LogicalKeyboardKey.digit7, control: true): () {
        _navigateTo(AppDestination.stashes);
      },
      const SingleActivator(LogicalKeyboardKey.digit8, control: true): () {
        _navigateTo(AppDestination.tags);
      },
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
        _navigateTo(AppDestination.settings);
      },
    };
  }

  /// Navigate to destination
  void _navigateTo(AppDestination destination) {
    ref.read(navigationDestinationProvider.notifier).state = destination;
  }

  /// Show command palette
  void _showCommandPalette(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      builder: (context) => const CommandPalette(),
    );
  }

  /// Show repository switcher dialog
  void _showRepositorySwitcher(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RepositorySwitcherDialog(),
    );
  }

  /// Build content for current destination
  Widget _buildContent(AppDestination destination) {
    switch (destination) {
      case AppDestination.workspaces:
        return const WorkspacesScreen();
      case AppDestination.repositories:
        return const RepositoriesScreen();
      case AppDestination.changes:
        return const ChangesScreen();
      case AppDestination.history:
        return const HistoryScreen();
      case AppDestination.browse:
        return const BrowseScreen();
      case AppDestination.branches:
        return const BranchesScreen();
      case AppDestination.stashes:
        return const StashesScreen();
      case AppDestination.tags:
        return const TagsScreen();
      case AppDestination.settings:
        return const SettingsScreen();
    }
  }

  /// Build an icon with an optional badge
  Widget _buildIconWithBadge(BuildContext context, Widget icon, int? count) {
    if (count == null || count == 0) {
      return icon;
    }

    return BaseIconBadge(
      count: count,
      variant: BadgeVariant.danger,
      child: icon,
    );
  }

  /// Build a git operation button
  Widget _buildGitOperationButton(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return BaseIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      size: ButtonSize.small,
      variant: ButtonVariant.secondary,
    );
  }

  /// Perform fetch operation
  Future<void> _performFetch(WidgetRef ref) async {
    // Get repositories to operate on (either selected or current)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    List<WorkspaceRepository> repositoriesToFetch;
    if (selectedPaths.isNotEmpty) {
      // Use selected repositories
      repositoriesToFetch = allRepositories
          .where((repo) => selectedPaths.contains(repo.path))
          .toList();
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      final currentRepo = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
      repositoriesToFetch = [currentRepo];
    }

    if (repositoriesToFetch.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToFetch) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(gitExecutablePath: gitExecutablePath);

    final results = await showBatchOperationProgressDialog(
      context,
      title: 'Fetch ${repositoriesToFetch.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToFetch,
      operation: (onProgress) => service.fetchAll(
        repositoriesToFetch,
        statuses,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }

      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Fetched successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }
    }
  }

  /// Perform pull operation
  Future<void> _performPull(WidgetRef ref) async {
    // Get repositories to operate on (either selected or current)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    List<WorkspaceRepository> repositoriesToPull;
    if (selectedPaths.isNotEmpty) {
      // Use selected repositories
      repositoriesToPull = allRepositories
          .where((repo) => selectedPaths.contains(repo.path))
          .toList();
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      final currentRepo = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
      repositoriesToPull = [currentRepo];
    }

    if (repositoriesToPull.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToPull) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(gitExecutablePath: gitExecutablePath);

    final results = await showBatchOperationProgressDialog(
      context,
      title: 'Pull ${repositoriesToPull.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToPull,
      operation: (onProgress) => service.pullAll(
        repositoriesToPull,
        statuses,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Pulled successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform push operation
  Future<void> _performPush(WidgetRef ref) async {
    // Get repositories to operate on (either selected or current)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    List<WorkspaceRepository> repositoriesToPush;
    if (selectedPaths.isNotEmpty) {
      // Use selected repositories
      repositoriesToPush = allRepositories
          .where((repo) => selectedPaths.contains(repo.path))
          .toList();
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      final currentRepo = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
      repositoriesToPush = [currentRepo];
    }

    if (repositoriesToPush.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToPush) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(gitExecutablePath: gitExecutablePath);

    final results = await showBatchOperationProgressDialog(
      context,
      title: 'Push ${repositoriesToPush.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToPush,
      operation: (onProgress) => service.pushAll(
        repositoriesToPush,
        statuses,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Pushed successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform create branch operation
  Future<void> _performCreateBranch(WidgetRef ref) async {
    // Get repositories to operate on (either selected or current)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    List<WorkspaceRepository> repositoriesToCreateBranch;
    if (selectedPaths.isNotEmpty) {
      // Use selected repositories
      repositoriesToCreateBranch = allRepositories
          .where((repo) => selectedPaths.contains(repo.path))
          .toList();
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      final currentRepo = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
      repositoriesToCreateBranch = [currentRepo];
    }

    if (repositoriesToCreateBranch.isEmpty) return;
    if (!context.mounted) return;

    // Show create branch dialog
    final result = await showCreateBranchDialog(
      context,
      repositories: repositoriesToCreateBranch,
    );

    if (result == null || !context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(gitExecutablePath: gitExecutablePath);

    final results = await showBatchOperationProgressDialog(
      context, // ignore: use_build_context_synchronously
      title: 'Creating Branch: ${result.fullBranchName}',
      repositories: repositoriesToCreateBranch,
      operation: (onProgress) => service.createBranch(
        repositoriesToCreateBranch,
        branchName: result.branchName,
        prefix: result.prefix,
        setUpstream: result.setUpstream,
        checkout: result.checkout,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Branch created successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Refresh branch providers to update branch switcher
      ref.read(gitActionsProvider).refreshBranches();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform create pull request operation
  Future<void> _performCreatePR(WidgetRef ref) async {
    // Get repository to operate on (only supports single repository)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    WorkspaceRepository? repository;
    if (selectedPaths.isNotEmpty) {
      // Only support single repository selection for PR creation
      if (selectedPaths.length > 1) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Pull request creation only supports single repository selection',
          );
        }
        return;
      }
      repository = allRepositories.firstWhere(
        (repo) => repo.path == selectedPaths.first,
        orElse: () => WorkspaceRepository.fromPath(selectedPaths.first),
      );
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      repository = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final gitService = GitService(repository.path, gitExecutablePath: gitExecutablePath);

    try {
      // Get current branch
      final branchResult = await gitService.getCurrentBranch();

      // Handle result
      String? currentBranch;
      branchResult.when(
        success: (branch) => currentBranch = branch,
        failure: (msg, error, stackTrace) {
          if (context.mounted) {
            NotificationService.showError(
              context,
              'Cannot create PR: $msg',
            );
          }
        },
      );

      // If branch retrieval failed, return early
      if (currentBranch == null) return;

      // Get available branches (including remote)
      final branchesResult = await gitService.getAllBranches();

      // Handle result
      List<GitBranch>? branches;
      branchesResult.when(
        success: (List<GitBranch> branchList) => branches = branchList,
        failure: (msg, error, stackTrace) {
          if (context.mounted) {
            NotificationService.showError(
              context,
              'Cannot load branches: $msg',
            );
          }
        },
      );

      // If branch loading failed, return early
      if (branches == null) return;

      // Show create PR dialog
      if (!context.mounted) return;
      final result = await showCreatePullRequestDialog(
        context, // ignore: use_build_context_synchronously
        currentBranch: currentBranch!,
        availableBranches: branches!,
      );

      if (result == null || !context.mounted) return;

      try {
        // Get remote URL for platform detection
        final remoteUrl = await gitService.getRemoteUrl('origin');
        if (remoteUrl == null || remoteUrl.isEmpty) {
          if (!context.mounted) return;
          NotificationService.showError(
            context, // ignore: use_build_context_synchronously
            'Cannot create PR: No remote URL found for origin',
          );
          return;
        }

        // Open PR creation in browser
        final success = await GitPlatformService.openPRCreation(
          remoteUrl: remoteUrl,
          sourceBranch: currentBranch!,
          targetBranch: result.baseBranch,
          title: result.title,
          description: result.description,
          draft: result.draft,
        );

        if (context.mounted) {
          // Clear selection after the current frame to avoid rebuilding while dialog is closing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
            }
          });

          if (!success) {
            // Show error message
            NotificationService.showError(
              context, // ignore: use_build_context_synchronously
              'Failed to open pull request creation. Platform may not be supported or URL is invalid.',
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          // Show error message
          NotificationService.showError(
            context, // ignore: use_build_context_synchronously
            'Failed to create pull request: ${e.toString()}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context, // ignore: use_build_context_synchronously
          'Error: ${e.toString()}',
        );
      }
    }
  }

  /// Show merge branches dialog
  Future<void> _performMergeBranches(BuildContext context) async {
    await showMergeBranchesDialog(context);
  }
}
