import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_filter_chip.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_diff_viewer.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/git_service.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/commit.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/multi_select_mixin.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/utils/result_extensions.dart';
import 'widgets/commit_list_item.dart';
import 'widgets/commit_details_panel.dart';
import '../tags/dialogs/create_tag_dialog.dart';
import 'widgets/file_tree_panel.dart';
import 'widgets/history_empty_states.dart';
import 'providers/history_search_provider.dart';
import 'providers/selected_commit_provider.dart';
import 'models/history_search_filter.dart';
import '../../core/services/logger_service.dart';
import 'dialogs/advanced_search_dialog.dart';
import 'dialogs/squash_commits_dialog.dart';
import 'dialogs/reset_mode_dialog.dart';
import 'dialogs/force_push_dialog.dart';
import '../../shared/widgets/standard_app_bar.dart';

/// History screen - Commit log and history
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final _selectionManager = MultiSelectManager<String>();
  final _scrollController = ScrollController();
  bool _fabIsExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _collapseFAB() {
    if (_fabIsExpanded) {
      setState(() {
        _fabIsExpanded = false;
      });
    }
  }

  void _toggleFAB() {
    setState(() {
      _fabIsExpanded = !_fabIsExpanded;
    });
  }

  void _moveSelection(List<GitCommit> commits, int delta) {
    if (commits.isEmpty) return;

    final currentIndex = ref.read(selectedCommitIndexProvider);
    int newIndex;

    if (currentIndex == -1 && delta > 0) {
      newIndex = 0;
    } else {
      newIndex = (currentIndex + delta).clamp(0, commits.length - 1);
    }

    ref.read(selectedCommitIndexProvider.notifier).state = newIndex;
    ref.read(selectedCommitProvider.notifier).state = commits[newIndex];
  }

  KeyEventResult _handleKeyEvent(
    List<GitCommit> commits,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ESC key dismissal for FAB
    if (event.logicalKey == LogicalKeyboardKey.escape && _fabIsExpanded) {
      _collapseFAB();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(commits, 1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(commits, -1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        ref.read(selectedCommitProvider) != null) {
      // Enter key could be used for additional actions in the future
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final filteredCommitsAsync = ref.watch(filteredCommitsProvider);
    final searchFilter = ref.watch(historySearchFilterProvider);

    // Update search controller directly when tag filter is active
    // This handles both initial navigation from tags view and filter changes
    if (searchFilter.tags != null && searchFilter.tags!.isNotEmpty) {
      final expectedText = 'tag:${searchFilter.tags!.first}';
      if (_searchController.text != expectedText) {
        Logger.debug('[HistoryScreen] Setting search text to: $expectedText');
        // Use post-frame callback to avoid modifying state during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _searchController.text != expectedText) {
            _searchController.text = expectedText;
          }
        });
      }
    }

    // Listen for filter changes from external sources (like tags view)
    ref.listen<HistorySearchFilter>(historySearchFilterProvider, (previous, next) {
      Logger.debug('[HistoryScreen] Filter changed - tags: ${next.tags}');
      // Update search controller if tag filter is set
      if (next.tags != null && next.tags!.isNotEmpty) {
        final expectedText = 'tag:${next.tags!.first}';
        if (_searchController.text != expectedText) {
          Logger.debug('[HistoryScreen] Listener updating search text to: $expectedText');
          _searchController.text = expectedText;
        }
      }
    });

    // Listen for filtered commits to auto-select when tag filter is active
    ref.listen<AsyncValue<List<GitCommit>>>(filteredCommitsProvider, (previous, next) {
      next.whenData((commits) {
        Logger.debug('[HistoryScreen] Filtered commits loaded: ${commits.length} commits');
        // If we have a tag filter and exactly 1 commit, auto-select it
        if (searchFilter.tags != null && searchFilter.tags!.isNotEmpty && commits.length == 1) {
          Logger.debug('[HistoryScreen] Auto-selecting commit: ${commits.first.shortHash}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedCommitIndexProvider.notifier).state = 0;
            ref.read(selectedCommitProvider.notifier).state = commits.first;
          });
        }
      });
    });

    // No repository open
    if (repositoryPath == null) {
      return const NoRepositoryEmptyState();
    }

    return Scaffold(
      appBar: StandardAppBar(
        title: AppDestination.history.label(context),
        onRefresh: () => ref.invalidate(commitHistoryProvider),
        moreMenuItems: const [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar and filters
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Search bar row
                  Row(
                    children: [
                      Expanded(
                        child: BaseTextField(
                          controller: _searchController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.hintTextSearchCommits,
                          prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                          showClearButton: _searchController.text.isNotEmpty,
                          onChanged: (query) {
                            setState(() {}); // Update suffix icon
                            if (query.isEmpty) {
                              ref
                                      .read(
                                        historySearchFilterProvider.notifier,
                                      )
                                      .state =
                                  const HistorySearchFilter.empty();
                            } else {
                              // Parse and apply search
                              final searchService = ref.read(
                                historySearchServiceProvider,
                              );
                              final filter = searchService.parseQuery(query);
                              ref
                                      .read(
                                        historySearchFilterProvider.notifier,
                                      )
                                      .state =
                                  filter;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingM),
                      // Advanced search button
                      BaseIconButton(
                        icon: PhosphorIconsRegular.faders,
                        tooltip: AppLocalizations.of(context)!.advancedSearch,
                        onPressed: () => _showAdvancedSearch(context),
                        variant: ButtonVariant.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.paddingS),

                  // Quick filter chips
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.funnel,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      BodySmallLabel(
                        AppLocalizations.of(context)!.quickFilters,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      Expanded(
                        child: Wrap(
                          spacing: AppTheme.paddingS,
                          children: [
                            _buildQuickFilter(
                              AppLocalizations.of(context)!.today,
                              HistorySearchFilter.today(),
                            ),
                            _buildQuickFilter(
                              AppLocalizations.of(context)!.thisWeek,
                              HistorySearchFilter.thisWeek(),
                            ),
                            _buildQuickFilter(
                              AppLocalizations.of(context)!.thisMonth,
                              HistorySearchFilter.thisMonth(),
                            ),
                            _buildQuickFilter(
                              AppLocalizations.of(context)!.last30Days,
                              HistorySearchFilter.last30Days(),
                            ),
                            if (searchFilter.isNotEmpty)
                              BaseActionChip(
                                label: AppLocalizations.of(context)!.clearFilters(
                                  searchFilter.activeFilterCount,
                                ),
                                icon: PhosphorIconsRegular.x,
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                          .read(
                                            historySearchFilterProvider
                                                .notifier,
                                          )
                                          .state =
                                      const HistorySearchFilter.empty();
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: filteredCommitsAsync.when(
                data: (commits) {
                  if (commits.isEmpty) {
                    return searchFilter.isNotEmpty
                        ? _buildNoSearchResults(context)
                        : _buildNoCommits(context);
                  }

                  return _buildCommitHistory(context, commits);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildError(context, error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCommits(BuildContext context) {
    return const NoCommitsState();
  }

  Widget _buildError(BuildContext context, Object error) {
    return HistoryErrorState(error: error);
  }

  Widget _buildCommitHistory(BuildContext context, List<GitCommit> commits) {
    final selectedCount = _selectionManager.selectedCount;
    final l10n = AppLocalizations.of(context)!;

    // Build FAB actions based on selection
    final fabActions = <DiffViewerAction>[
      // Squash Commits (requires 2+ commits)
      if (selectedCount >= 2)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowsInLineVertical,
          label: l10n.squashCommits,
          onPressed: () => _showSquashDialog(context, commits),
        ),
      // Cherry-pick (requires 1+ commits)
      if (selectedCount > 0)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowBendDownRight,
          label: l10n.cherryPick,
          onPressed: () => _performCherryPick(context, commits),
        ),
      // Revert (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.revert,
          onPressed: () => _performRevert(context, commits),
        ),
      // Reset to Here (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.resetToHere,
          onPressed: () => _performReset(context, commits),
        ),
      // Create Tag (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.tag,
          label: l10n.createTag,
          onPressed: () => _showCreateTagDialog(context, commits.first),
        ),
    ];

    // Main content widget
    final contentWidget = Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(commits, node, event),
      child: Row(
        children: [
          // Commit list (left side)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // List header
                  Container(
                    padding: const EdgeInsets.all(AppTheme.paddingL),
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
                        Icon(
                          PhosphorIconsRegular.listBullets,
                          size: AppTheme.iconS,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                        TitleSmallLabel(
                          AppLocalizations.of(
                            context,
                          )!.commitsCount(commits.length),
                        ),
                      ],
                    ),
                  ),

                  // Commit list
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final selectedCommit = ref.watch(
                          selectedCommitProvider,
                        );
                        final currentBranch = ref
                            .watch(currentBranchProvider)
                            .value;

                        return ListView.builder(
                          controller: _scrollController,
                          itemCount: commits.length,
                          itemBuilder: (context, index) {
                            final commit = commits[index];
                            final isSelected =
                                selectedCommit?.hash == commit.hash;
                            final isMultiSelected = _selectionManager
                                .isItemSelected(commit.hash);

                            return CommitListItem(
                              commit: commit,
                              isSelected: isSelected,
                              isMultiSelected: isMultiSelected,
                              currentBranch: currentBranch,
                              onTap: () {
                                // Handle platform-aware multi-selection
                                final isCtrlPressed =
                                    MultiSelectManager.isMultiSelectModifierPressed();
                                final isShiftPressed =
                                    MultiSelectManager.isRangeSelectModifierPressed();

                                if (isCtrlPressed || isShiftPressed) {
                                  // Multi-select mode
                                  _selectionManager.handleItemClick(
                                    item: commit.hash,
                                    allItems: commits
                                        .map((c) => c.hash)
                                        .toList(),
                                    isControlPressed: isCtrlPressed,
                                    isShiftPressed: isShiftPressed,
                                    onSelectionChanged: () => setState(() {}),
                                  );
                                } else {
                                  // Single selection mode - select commit in both providers
                                  _selectionManager.handleItemClick(
                                    item: commit.hash,
                                    allItems: commits
                                        .map((c) => c.hash)
                                        .toList(),
                                    isControlPressed: false,
                                    isShiftPressed: false,
                                    onSelectionChanged: () => setState(() {}),
                                  );
                                  ref
                                          .read(selectedCommitProvider.notifier)
                                          .state =
                                      commit;
                                  ref
                                          .read(
                                            selectedCommitIndexProvider
                                                .notifier,
                                          )
                                          .state =
                                      index;
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Commit details (middle)
          Expanded(
            flex: 2,
            child: Consumer(
              builder: (context, ref, child) {
                final selectedCommit = ref.watch(selectedCommitProvider);

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: selectedCommit == null
                      ? _buildNoCommitSelected(context)
                      : CommitDetailsPanel(commit: selectedCommit),
                );
              },
            ),
          ),

          // File tree (right side)
          Expanded(
            flex: 2,
            child: Consumer(
              builder: (context, ref, child) {
                final selectedCommit = ref.watch(selectedCommitProvider);

                return selectedCommit == null
                    ? _buildNoCommitSelected(context)
                    : FileTreePanel(commitHash: selectedCommit.hash);
              },
            ),
          ),
        ],
      ),
    );

    // Wrap with Stack and FAB if we have actions
    if (fabActions.isEmpty) {
      return contentWidget;
    }

    // Wrap with dismissal behaviors: tap-outside and scroll (ESC handled in FAB widget)
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Collapse FAB when scrolling starts
        if (notification is ScrollStartNotification && _fabIsExpanded) {
          _collapseFAB();
        }
        return false; // Allow notification to continue bubbling
      },
      child: GestureDetector(
        // Tap-outside dismissal
        onTap: _collapseFAB,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            contentWidget,
            // Draggable Speed Dial FAB (ESC key handled internally)
            _DraggableSpeedDial(
              actions: fabActions,
              isExpanded: _fabIsExpanded,
              onToggle: _toggleFAB,
              onCollapse: _collapseFAB,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCommitSelected(BuildContext context) {
    return const NoCommitSelectedState();
  }

  Widget _buildNoSearchResults(BuildContext context) {
    return NoSearchResultsState(
      onClearFilters: () {
        _searchController.clear();
        ref.read(historySearchFilterProvider.notifier).state =
            const HistorySearchFilter.empty();
        setState(() {});
      },
    );
  }

  Widget _buildQuickFilter(String label, HistorySearchFilter filter) {
    return BaseActionChip(
      label: label,
      icon: PhosphorIconsRegular.calendar,
      onPressed: () {
        ref.read(historySearchFilterProvider.notifier).state = filter;
      },
    );
  }

  void _showAdvancedSearch(BuildContext context) {
    final currentFilter = ref.read(historySearchFilterProvider);

    showDialog(
      context: context,
      builder: (context) => AdvancedSearchDialog(initialFilter: currentFilter),
    );
  }

  Future<void> _showSquashDialog(
    BuildContext context,
    List<GitCommit> commits,
  ) async {
    final result = await showSquashCommitsDialog(
      context,
      commits: commits,
      selectedHashes: _selectionManager.selectedItems,
    );

    if (result == true && mounted) {
      // Refresh providers to update UI
      ref.invalidate(commitHistoryProvider);
      ref.invalidate(localBranchesProvider);
      ref.invalidate(currentBranchProvider);

      // Clear selection
      _selectionManager.clearSelection(() => setState(() {}));
    }
  }

  Future<void> _showCreateTagDialog(
    BuildContext context,
    GitCommit commit,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateTagDialog(
        commitHash: commit.hash,
        commitMessage: commit.subject,
      ),
    );

    if (result != null && result['name'] != null && mounted) {
      final tagName = result['name'] as String;
      if (tagName.isEmpty) return;

      if (result['annotated'] == true) {
        await ref.read(gitActionsProvider).createAnnotatedTag(
          tagName,
          message: result['message'] as String,
          commitHash: commit.hash,
        );
      } else {
        await ref.read(gitActionsProvider).createLightweightTag(
          tagName,
          commitHash: commit.hash,
        );
      }

      // Refresh tags provider
      ref.invalidate(tagsProvider);
    }
  }

  Future<void> _performCherryPick(
    BuildContext context,
    List<GitCommit> commits,
  ) async {
    final selectedHashes = _selectionManager.selectedItems.toList();

    if (selectedHashes.isEmpty) return;

    // Cherry-pick each commit in order
    for (final hash in selectedHashes) {
      await ref.read(gitActionsProvider).cherryPickCommit(hash);
    }

    // Refresh providers to update UI
    ref.invalidate(commitHistoryProvider);
    ref.invalidate(localBranchesProvider);
    ref.invalidate(currentBranchProvider);

    // Clear selection
    _selectionManager.clearSelection(() => setState(() {}));
  }

  Future<void> _performRevert(
    BuildContext context,
    List<GitCommit> commits,
  ) async {
    if (_selectionManager.selectedCount != 1) return;

    final hash = _selectionManager.selectedItems.first;

    await ref.read(gitActionsProvider).revertCommit(hash);

    // Refresh providers to update UI
    ref.invalidate(commitHistoryProvider);
    ref.invalidate(localBranchesProvider);
    ref.invalidate(currentBranchProvider);

    // Clear selection
    _selectionManager.clearSelection(() => setState(() {}));
  }

  Future<void> _performReset(
    BuildContext context,
    List<GitCommit> commits,
  ) async {
    if (_selectionManager.selectedCount != 1) return;

    final hash = _selectionManager.selectedItems.first;
    final commit = commits.firstWhere((c) => c.hash == hash);

    // Show dialog to choose reset mode
    final mode = await _showResetModeDialog(context, commit);
    if (mode == null) return;

    await ref.read(gitActionsProvider).resetToCommit(hash, mode: mode);

    // Refresh providers to update UI
    ref.invalidate(commitHistoryProvider);
    ref.invalidate(localBranchesProvider);
    ref.invalidate(currentBranchProvider);

    // Clear selection
    _selectionManager.clearSelection(() => setState(() {}));

    // After reset, ask if user wants to force push to remote
    if (!mounted || !context.mounted) return;

    final shouldForcePush = await showDialog<bool>(
      context: context,
      builder: (context) => const ForcePushDialog(),
    );

    if (shouldForcePush == true) {
      // Force push to remote
      final currentBranch = ref.read(currentBranchProvider).value;
      if (currentBranch == null) return;

      await ref.read(gitActionsProvider).pushRemote(
        force: true,
        remote: 'origin',
        branch: currentBranch,
      );

      if (mounted) {
        context.showSuccessIfMounted(
          AppLocalizations.of(context)!.forcePushSuccessful,
        );
      }
    }
  }

  Future<ResetMode?> _showResetModeDialog(
    BuildContext context,
    GitCommit commit,
  ) {
    return showDialog<ResetMode>(
      context: context,
      builder: (context) => ResetModeDialog(commit: commit),
    );
  }
}

/// Draggable Speed Dial FAB for history actions
class _DraggableSpeedDial extends StatefulWidget {
  final List<DiffViewerAction> actions;
  final bool isExpanded;  // Controlled by parent
  final VoidCallback onToggle;  // Callback to toggle expansion
  final VoidCallback onCollapse;  // Callback to collapse (for actions)

  const _DraggableSpeedDial({
    required this.actions,
    required this.isExpanded,
    required this.onToggle,
    required this.onCollapse,
  });

  @override
  State<_DraggableSpeedDial> createState() => _DraggableSpeedDialState();
}

class _DraggableSpeedDialState extends State<_DraggableSpeedDial> {
  Offset _position = const Offset(AppTheme.paddingM, AppTheme.paddingM); // Default position (from bottom-right)
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: _position.dx,
      bottom: _position.dy,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          // ESC key dismissal
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              widget.isExpanded) {
            widget.onCollapse();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Update position by subtracting delta (since we're using right/bottom positioning)
              _position = Offset(
                (_position.dx - details.delta.dx).clamp(AppTheme.paddingM, MediaQuery.of(context).size.width - 80),
                (_position.dy - details.delta.dy).clamp(AppTheme.paddingM, MediaQuery.of(context).size.height - 80),
              );
            });
          },
          onTap: () {
            // Request focus when tapped so ESC key works
            _focusNode.requestFocus();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expanded action buttons
              if (widget.isExpanded)
                ...widget.actions.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.paddingS + AppTheme.paddingXS),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(AppTheme.paddingXS),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingS + AppTheme.paddingXS,
                              vertical: AppTheme.paddingS,
                            ),
                            child: BodySmallLabel(action.label),
                          ),
                        ),
                        const SizedBox(width: AppTheme.paddingS + AppTheme.paddingXS),
                        // Action button
                        FloatingActionButton.small(
                          heroTag: action.label,
                          onPressed: () {
                            action.onPressed();
                            // Collapse after action
                            widget.onCollapse();
                          },
                          child: Icon(action.icon),
                        ),
                      ],
                    ),
                  )),
              // Main FAB
              FloatingActionButton(
                heroTag: 'main_fab',
                onPressed: () {
                  widget.onToggle();
                  // Request focus so ESC key works
                  _focusNode.requestFocus();
                },
                child: AnimatedRotation(
                  turns: widget.isExpanded ? 0.125 : 0, // 45 degrees when expanded
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.isExpanded
                        ? PhosphorIconsRegular.x
                        : PhosphorIconsRegular.list,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
