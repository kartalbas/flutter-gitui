import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_filter_chip.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_diff_viewer.dart';
import '../../shared/components/base_menu_item.dart';
import '../../core/constants/app_constants.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/git_service.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/commit.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/services/notification_service.dart';
import 'widgets/commit_list_item.dart';
import 'widgets/commit_details_panel.dart';
import '../tags/dialogs/create_tag_dialog.dart';
import 'widgets/file_tree_panel.dart';
import 'widgets/commit_diff_panel.dart';
import 'widgets/history_empty_states.dart';
import 'providers/history_search_provider.dart';
import 'providers/commit_selection_provider.dart';
import 'services/commit_action_runner.dart';
import 'models/history_search_filter.dart';
import '../../core/services/logger_service.dart';
import 'dialogs/advanced_search_dialog.dart';
import 'dialogs/squash_commits_dialog.dart';
import 'dialogs/reset_mode_dialog.dart';
import 'dialogs/force_push_dialog.dart';
import 'dialogs/create_branch_from_commit_dialog.dart';
import 'dialogs/compare_commits_dialog.dart';
import '../../shared/widgets/standard_app_bar.dart';

/// History screen - Commit log and history
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _fabIsExpanded = false;
  Timer? _searchDebounce;

  /// Marks the primary-selected row so a keyboard-opened context menu can
  /// anchor to it even though no cursor position exists.
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applySearch(String query) {
    final notifier = ref.read(historySearchFilterProvider.notifier);
    if (query.isEmpty) {
      notifier.state = const HistorySearchFilter.empty();
    } else {
      final searchService = ref.read(historySearchServiceProvider);
      notifier.state = searchService.parseQuery(query);
    }
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

    // Shift+F10 and the dedicated menu key open the same menu a right-click
    // does, anchored to the selected row. The menu itself is arrow-key
    // navigable, which is what makes every entry reachable without a mouse.
    if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
        (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed)) {
      if (ref.read(commitSelectionProvider).resolve(commits).isEmpty) {
        return KeyEventResult.ignored;
      }
      unawaited(_showCommitContextMenu(commits, _selectedRowMenuPosition()));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ref.read(commitSelectionProvider.notifier).move(commits, 1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ref.read(commitSelectionProvider.notifier).move(commits, -1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        // Resolved, not raw: a stale selection the screen no longer shows must
        // not claim the key while the view says nothing is selected.
        ref.read(commitSelectionProvider).resolve(commits).isNotEmpty) {
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
    ref.listen<HistorySearchFilter>(historySearchFilterProvider, (
      previous,
      next,
    ) {
      Logger.debug('[HistoryScreen] Filter changed - tags: ${next.tags}');
      // Update search controller if tag filter is set
      if (next.tags != null && next.tags!.isNotEmpty) {
        final expectedText = 'tag:${next.tags!.first}';
        if (_searchController.text != expectedText) {
          Logger.debug(
            '[HistoryScreen] Listener updating search text to: $expectedText',
          );
          _searchController.text = expectedText;
        }
      }
    });

    // Listen for filtered commits to auto-select when tag filter is active
    ref.listen<AsyncValue<List<GitCommit>>>(filteredCommitsProvider, (
      previous,
      next,
    ) {
      next.whenData((commits) {
        Logger.debug(
          '[HistoryScreen] Filtered commits loaded: ${commits.length} commits',
        );
        // If we have a tag filter and exactly 1 commit, auto-select it
        if (searchFilter.tags != null &&
            searchFilter.tags!.isNotEmpty &&
            commits.length == 1) {
          Logger.debug(
            '[HistoryScreen] Auto-selecting commit: ${commits.first.shortHash}',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(commitSelectionProvider.notifier)
                .selectSingle(commits.first.hash);
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
                            // Filtering is pure over the loaded window and
                            // never invokes git, but fuzzy-scoring every
                            // loaded commit still stutters typing on large
                            // windows, so bursts are coalesced.
                            _searchDebounce?.cancel();
                            if (query.isEmpty) {
                              // Clearing restores the full history at once.
                              _applySearch(query);
                            } else {
                              _searchDebounce = Timer(
                                AppConstants.debounceMilliseconds,
                                () {
                                  if (mounted) _applySearch(query);
                                },
                              );
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
                                label: AppLocalizations.of(
                                  context,
                                )!.clearFilters(searchFilter.activeFilterCount),
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
    // One resolution of the selection feeds the highlight, the details panel,
    // the action button and every action, so none of them can act on a commit
    // the user is not looking at.
    final selection = ref.watch(commitSelectionProvider).resolve(commits);
    final selectedHashes = selection.hashes;
    final selectedCount = selection.count;
    final l10n = AppLocalizations.of(context)!;

    // A search only covers the loaded window, so the header reports "matched
    // X of Y loaded" instead of implying the whole history was searched.
    final searchFilter = ref.watch(historySearchFilterProvider);
    final loadedCount =
        ref.watch(commitWindowProvider).value?.length ?? commits.length;

    // Lanes are positions in the exact row sequence the graph pass walked.
    // The in-memory filter only ever removes rows, so an unchanged length
    // means the displayed list is the window itself; anything narrower falls
    // back to the plain dot instead of drawing lanes to missing neighbors.
    final graph = commits.length == loadedCount
        ? ref.watch(commitGraphProvider).value
        : null;

    // Build FAB actions based on selection
    final fabActions = <DiffViewerAction>[
      // Squash Commits (requires 2+ commits)
      if (selectedCount >= 2)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowsInLineVertical,
          label: l10n.squashCommits,
          onPressed: () => _showSquashDialog(context, selection),
        ),
      // Cherry-pick (requires 1+ commits)
      if (selectedCount > 0)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowBendDownRight,
          label: l10n.cherryPick,
          onPressed: () => _performCherryPick(context, selection),
        ),
      // Revert (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.revert,
          onPressed: () => _performRevert(context, selection),
        ),
      // Reset to Here (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.resetToHere,
          onPressed: () => _performReset(context, selection),
        ),
      // Create Tag (requires exactly 1 commit)
      if (selectedCount == 1)
        DiffViewerAction(
          icon: PhosphorIconsRegular.tag,
          label: l10n.createTag,
          onPressed: () {
            final commit = selection.single;
            if (commit == null) return;
            _showCreateTagDialog(context, commit);
          },
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
                          searchFilter.isNotEmpty
                              ? l10n.commitsMatchedOfLoaded(
                                  commits.length,
                                  loadedCount,
                                )
                              : l10n.commitsCount(commits.length),
                        ),
                      ],
                    ),
                  ),

                  // Commit list
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final currentBranch = ref
                            .watch(currentBranchProvider)
                            .value;

                        return ListView.builder(
                          controller: _scrollController,
                          itemCount: commits.length,
                          itemBuilder: (context, index) {
                            final commit = commits[index];
                            final isPrimary =
                                selection.primary?.hash == commit.hash;

                            return CommitListItem(
                              // The key follows the primary row so the
                              // keyboard path can anchor the context menu to
                              // its on-screen position.
                              key: isPrimary ? _selectedRowKey : null,
                              commit: commit,
                              isSelected: isPrimary,
                              isMultiSelected: selectedHashes.contains(
                                commit.hash,
                              ),
                              currentBranch: currentBranch,
                              graphRow: graph?.rowFor(commit.hash),
                              graphLaneCount: graph?.laneCount ?? 0,
                              onSecondaryTap: (position) =>
                                  _onCommitContextClick(
                                    commits,
                                    commit,
                                    position,
                                  ),
                              onTap: () => ref
                                  .read(commitSelectionProvider.notifier)
                                  .handleClick(
                                    hash: commit.hash,
                                    displayedHashes: [
                                      for (final c in commits) c.hash,
                                    ],
                                    isControlPressed:
                                        CommitSelectionNotifier.isMultiSelectModifierPressed(),
                                    isShiftPressed:
                                        CommitSelectionNotifier.isRangeSelectModifierPressed(),
                                  ),
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

          // Metadata and changed files share the middle column so the right
          // column can hold the highlighted file's diff in place - seeing a
          // commit's changes no longer requires opening a dialog per file.
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
              child: selection.primary == null
                  ? _buildNoCommitSelected(context)
                  : Column(
                      children: [
                        Expanded(
                          child: CommitDetailsPanel(commit: selection.primary!),
                        ),
                        const SizedBox(height: AppTheme.paddingS),
                        Expanded(
                          child: FileTreePanel(
                            commitHash: selection.primary!.hash,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // The highlighted file's diff (right side)
          Expanded(
            flex: 3,
            child: selection.primary == null
                ? _buildNoCommitSelected(context)
                : CommitDiffPanel(commitHash: selection.primary!.hash),
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

  /// Right-click follows the file-manager convention: on a commit already
  /// inside the selection the menu acts on the whole selection, on any other
  /// commit the click selects it first. Both paths go through the notifier,
  /// so the menu acts on the same resolved selection every surface shows.
  void _onCommitContextClick(
    List<GitCommit> commits,
    GitCommit commit,
    Offset position,
  ) {
    ref
        .read(commitSelectionProvider.notifier)
        .handleContextClick(hash: commit.hash, displayed: commits);
    unawaited(_showCommitContextMenu(commits, position));
  }

  /// Where a keyboard-opened context menu appears: on the selected row when
  /// it is on screen, otherwise over the list area, so the menu never opens
  /// at a stale or off-screen coordinate.
  Offset _selectedRowMenuPosition() {
    final rowBox = _selectedRowKey.currentContext?.findRenderObject();
    if (rowBox is RenderBox && rowBox.attached) {
      return rowBox.localToGlobal(
        Offset(AppTheme.paddingXL, rowBox.size.height / 2),
      );
    }
    final screen = MediaQuery.of(context).size;
    return Offset(screen.width / 3, screen.height / 3);
  }

  Future<void> _showCommitContextMenu(
    List<GitCommit> commits,
    Offset position,
  ) async {
    final selection = ref.read(commitSelectionProvider).resolve(commits);
    if (selection.isEmpty) return;

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    // A value-returning menu instead of per-item onTap callbacks: the action
    // runs after the menu route has closed, so its dialogs and notifications
    // are not torn down together with the menu.
    final action = await showMenu<_CommitContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: _buildCommitContextMenuItems(selection),
    );

    if (action == null || !mounted) return;
    await _runCommitContextAction(action, selection);
  }

  List<PopupMenuEntry<_CommitContextAction>> _buildCommitContextMenuItems(
    ResolvedCommitSelection selection,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    final count = selection.count;

    return [
      BaseMenuItem(
        value: _CommitContextAction.copySha,
        child: MenuItemContent(
          icon: PhosphorIconsRegular.copy,
          label: l10n.copySha,
        ),
      ),
      BaseMenuItem(
        value: _CommitContextAction.copyMessage,
        child: MenuItemContent(
          icon: PhosphorIconsRegular.chatText,
          label: l10n.copyCommitMessage,
        ),
      ),
      if (count == 1) ...[
        BaseMenuItem(
          value: _CommitContextAction.createBranch,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.gitBranch,
            label: l10n.createBranchFromCommit,
          ),
        ),
        BaseMenuItem(
          value: _CommitContextAction.createTag,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.tag,
            label: l10n.createTag,
          ),
        ),
      ],
      if (count == 2)
        BaseMenuItem(
          value: _CommitContextAction.compare,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.gitDiff,
            label: l10n.compareCommits,
          ),
        ),
      BaseMenuItem(
        value: _CommitContextAction.cherryPick,
        child: MenuItemContent(
          icon: PhosphorIconsRegular.arrowBendDownRight,
          label: l10n.cherryPick,
        ),
      ),
      // Everything below the divider rewrites or moves history. The visual
      // break plus the error color keeps a hand aiming at a copy entry from
      // landing on a reset by one pixel.
      const PopupMenuDivider(),
      if (count >= 2)
        BaseMenuItem(
          value: _CommitContextAction.squash,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.arrowsInLineVertical,
            label: l10n.squashCommits,
            iconColor: errorColor,
            labelColor: errorColor,
          ),
        ),
      if (count == 1) ...[
        BaseMenuItem(
          value: _CommitContextAction.revert,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            label: l10n.revert,
            iconColor: errorColor,
            labelColor: errorColor,
          ),
        ),
        BaseMenuItem(
          value: _CommitContextAction.reset,
          child: MenuItemContent(
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            label: l10n.resetToHere,
            iconColor: errorColor,
            labelColor: errorColor,
          ),
        ),
      ],
    ];
  }

  Future<void> _runCommitContextAction(
    _CommitContextAction action,
    ResolvedCommitSelection selection,
  ) async {
    switch (action) {
      case _CommitContextAction.copySha:
        await _copyCommitShas(context, selection);
      case _CommitContextAction.copyMessage:
        await _copyCommitMessages(context, selection);
      case _CommitContextAction.createBranch:
        await _showCreateBranchFromCommitDialog(context, selection);
      case _CommitContextAction.createTag:
        final commit = selection.single;
        if (commit != null) await _showCreateTagDialog(context, commit);
      case _CommitContextAction.compare:
        _showCompareCommitsDialog(context, selection);
      case _CommitContextAction.cherryPick:
        await _performCherryPick(context, selection);
      case _CommitContextAction.squash:
        await _showSquashDialog(context, selection);
      case _CommitContextAction.revert:
        await _performRevert(context, selection);
      case _CommitContextAction.reset:
        await _performReset(context, selection);
    }
  }

  /// Copying reads the repository without touching it, so it deliberately
  /// stays outside [_runCommitAction]: reloading four providers and clearing
  /// the selection over a clipboard write would throw away the very
  /// selection the user is still working with.
  Future<void> _copyCommitShas(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    if (selection.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(
        text: [for (final commit in selection.commits) commit.hash].join('\n'),
      ),
    );
    if (context.mounted) {
      NotificationService.showSuccess(
        context,
        AppLocalizations.of(context)!.shaCopiedToClipboard,
      );
    }
  }

  Future<void> _copyCommitMessages(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    if (selection.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(
        text: [
          for (final commit in selection.commits) commit.message,
        ].join('\n\n'),
      ),
    );
    if (context.mounted) {
      NotificationService.showSuccess(
        context,
        AppLocalizations.of(context)!.commitMessageCopiedToClipboard,
      );
    }
  }

  Future<void> _showCreateBranchFromCommitDialog(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    final commit = selection.single;
    if (commit == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateBranchFromCommitDialog(commit: commit),
    );
    if (result == null || !context.mounted) return;

    final branchName = result['branchName'] as String;
    final l10n = AppLocalizations.of(context)!;
    final didCreate = await _runCommitAction(
      context,
      invoke: () => ref
          .read(gitActionsProvider)
          .createBranch(
            branchName,
            startPoint: commit.hash,
            checkout: result['checkout'] as bool,
          ),
      describeFailure: l10n.createBranchError,
    );

    // Creating a branch changes nothing visible in the working tree, so
    // without an explicit confirmation the user cannot tell it happened.
    if (didCreate && context.mounted) {
      NotificationService.showSuccess(
        context,
        l10n.snackbarBranchCreatedSuccess(branchName),
      );
    }
  }

  void _showCompareCommitsDialog(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) {
    final commits = selection.commits;
    if (commits.length != 2) return;

    // Display order is newest first, so first and last map onto the newer
    // and older end of the range git log expects.
    showDialog(
      context: context,
      builder: (context) =>
          CompareCommitsDialog(newer: commits.first, older: commits.last),
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
    ResolvedCommitSelection selection,
  ) async {
    final result = await showSquashCommitsDialog(
      context,
      selectedCommits: selection.commits,
    );

    if (result == true && mounted) {
      // Refresh providers to update UI
      ref.invalidate(commitHistoryProvider);
      ref.invalidate(localBranchesProvider);
      ref.invalidate(currentBranchProvider);

      // The squashed commits no longer exist, so keeping them selected would
      // aim the next action at rewritten history.
      ref.read(commitSelectionProvider.notifier).clear();
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

    if (result == null || result['name'] == null || !context.mounted) return;
    final tagName = result['name'] as String;
    if (tagName.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    await _runCommitAction(
      context,
      invoke: () => result['annotated'] == true
          ? ref
                .read(gitActionsProvider)
                .createAnnotatedTag(
                  tagName,
                  message: result['message'] as String,
                  commitHash: commit.hash,
                )
          : ref
                .read(gitActionsProvider)
                .createLightweightTag(tagName, commitHash: commit.hash),
      describeFailure: l10n.tagCreatedError,
    );
  }

  /// The one sequence behind every commit action on this screen.
  ///
  /// Routing through [runCommitAction] means an action cannot skip the reload
  /// or swallow its error: every outcome invalidates the same providers, and a
  /// failure always reaches the user through the same notification. Returns
  /// whether the action succeeded, so multi-step flows (a reset offering a
  /// force push) know whether to continue.
  Future<bool> _runCommitAction(
    BuildContext context, {
    required Future<void> Function() invoke,
    required String Function(String error) describeFailure,
  }) async {
    final failure = await runCommitAction(
      invoke: invoke,
      refresh: () {
        // The union of everything a commit action can change: the commit
        // window itself plus the branch heads and tags decorating its rows.
        // One fixed set instead of five hand-picked ones is what keeps the
        // refresh impossible to forget.
        ref.invalidate(commitHistoryProvider);
        ref.invalidate(localBranchesProvider);
        ref.invalidate(currentBranchProvider);
        ref.invalidate(tagsProvider);
      },
      clearSelection: () => ref.read(commitSelectionProvider.notifier).clear(),
    );

    if (failure == null) return true;

    if (context.mounted) {
      NotificationService.showError(context, describeFailure(failure));
    }
    return false;
  }

  Future<void> _performCherryPick(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    if (selection.isEmpty) return;

    // The history list is newest-first, so replaying it as-is would apply a
    // commit before its ancestors.
    final ordered = selection.oldestFirst;

    final l10n = AppLocalizations.of(context)!;
    await _runCommitAction(
      context,
      // A failed pick leaves the repository mid-cherry-pick, so every later
      // pick would fail too: the first error stops the replay.
      invoke: () async {
        for (final commit in ordered) {
          await ref.read(gitActionsProvider).cherryPickCommit(commit.hash);
        }
      },
      describeFailure: l10n.cherryPickFailed,
    );
  }

  Future<void> _performRevert(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    final commit = selection.single;
    if (commit == null) return;

    final l10n = AppLocalizations.of(context)!;
    await _runCommitAction(
      context,
      invoke: () => ref.read(gitActionsProvider).revertCommit(commit.hash),
      describeFailure: l10n.revertFailed,
    );
  }

  Future<void> _performReset(
    BuildContext context,
    ResolvedCommitSelection selection,
  ) async {
    final commit = selection.single;
    if (commit == null) return;

    // Show dialog to choose reset mode
    final mode = await _showResetModeDialog(context, commit);
    if (mode == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final didReset = await _runCommitAction(
      context,
      invoke: () =>
          ref.read(gitActionsProvider).resetToCommit(commit.hash, mode: mode),
      describeFailure: l10n.resetFailed,
    );
    // A failed reset did not move the branch, so there is no divergence to
    // force-push away; offering one would overwrite the remote for nothing.
    if (!didReset) return;

    // A force push is only warranted when the branch tracks an upstream the reset
    // moved away from: a local-only repo has nothing to push, and a branch still
    // ahead of its upstream pushes normally.
    final branches = await ref.read(localBranchesProvider.future);
    final divergedFromUpstream = branches.where(
      (b) => b.isCurrent && b.hasUpstream && b.isBehind,
    );
    if (divergedFromUpstream.isEmpty) return;

    final branch = divergedFromUpstream.first;
    final upstream = branch.upstreamBranch!;
    final remoteSeparator = upstream.indexOf('/');
    if (remoteSeparator <= 0) return;

    if (!mounted || !context.mounted) return;

    // The dialog is the only barrier before remote history is overwritten, so
    // it is skipped only when the user explicitly turned the setting off.
    final shouldForcePush = ref.read(confirmForcePushProvider)
        ? await showDialog<bool>(
            context: context,
            builder: (context) => const ForcePushDialog(),
          )
        : true;

    if (shouldForcePush != true || !context.mounted) return;

    // The tracked remote need not be named "origin", and the upstream branch
    // need not share the local branch's name, so push an explicit refspec.
    final didPush = await _runCommitAction(
      context,
      invoke: () => ref
          .read(gitActionsProvider)
          .pushRemote(
            force: true,
            remote: upstream.substring(0, remoteSeparator),
            branch: '${branch.name}:${upstream.substring(remoteSeparator + 1)}',
          ),
      describeFailure: l10n.forcePushFailed,
    );

    // A force push changes nothing visible locally, so without an explicit
    // confirmation the user cannot tell it ran at all.
    if (didPush && context.mounted) {
      NotificationService.showSuccess(context, l10n.forcePushSuccessful);
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

/// Everything the commit context menu can do.
///
/// One value type for the whole menu keeps its conditions - which entries a
/// one-, two- or many-commit selection gets - in a single builder instead of
/// scattered across callbacks.
enum _CommitContextAction {
  copySha,
  copyMessage,
  createBranch,
  createTag,
  compare,
  cherryPick,
  squash,
  revert,
  reset,
}

/// Draggable Speed Dial FAB for history actions
class _DraggableSpeedDial extends StatefulWidget {
  final List<DiffViewerAction> actions;
  final bool isExpanded; // Controlled by parent
  final VoidCallback onToggle; // Callback to toggle expansion
  final VoidCallback onCollapse; // Callback to collapse (for actions)

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
  Offset _position = const Offset(
    AppTheme.paddingM,
    AppTheme.paddingM,
  ); // Default position (from bottom-right)
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
                (_position.dx - details.delta.dx).clamp(
                  AppTheme.paddingM,
                  MediaQuery.of(context).size.width - 80,
                ),
                (_position.dy - details.delta.dy).clamp(
                  AppTheme.paddingM,
                  MediaQuery.of(context).size.height - 80,
                ),
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
                ...widget.actions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppTheme.paddingS + AppTheme.paddingXS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(
                            AppTheme.paddingXS,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal:
                                  AppTheme.paddingS + AppTheme.paddingXS,
                              vertical: AppTheme.paddingS,
                            ),
                            child: BodySmallLabel(action.label),
                          ),
                        ),
                        const SizedBox(
                          width: AppTheme.paddingS + AppTheme.paddingXS,
                        ),
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
                  ),
                ),
              // Main FAB
              FloatingActionButton(
                heroTag: 'main_fab',
                onPressed: () {
                  widget.onToggle();
                  // Request focus so ESC key works
                  _focusNode.requestFocus();
                },
                child: AnimatedRotation(
                  turns: widget.isExpanded
                      ? 0.125
                      : 0, // 45 degrees when expanded
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
