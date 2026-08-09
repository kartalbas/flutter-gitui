import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_icon.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_layout.dart';
import '../../shared/components/base_filter_chip.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_speed_dial.dart';
import '../../core/constants/app_constants.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/git_service.dart';
import '../../core/git/destructive_action.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/commit.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/dialogs/confirm_destructive.dart';
import '../../shared/widgets/base_dismiss_scope.dart';
import '../../shared/widgets/base_focus_region.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/search_field_handoff.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/services/notification_service.dart';
import 'widgets/commit_list_item.dart';
import 'widgets/commit_details_panel.dart';
import '../../shared/dialogs/create_tag_dialog.dart';
import 'widgets/file_tree_panel.dart';
import 'widgets/commit_diff_panel.dart';
import 'widgets/history_empty_states.dart';
import 'providers/history_search_provider.dart';
import 'providers/commit_selection_provider.dart';
import 'providers/history_deep_search_provider.dart';
import 'widgets/deep_search_states.dart';
import 'widgets/history_list_footer.dart';
import 'services/commit_action_runner.dart';
import 'models/history_search_filter.dart';
import '../../core/services/logger_service.dart';
import 'dialogs/advanced_search_dialog.dart';
import 'dialogs/squash_commits_dialog.dart';
import 'dialogs/reset_mode_dialog.dart';
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
  bool _fabIsExpanded = false;
  Timer? _searchDebounce;

  /// Marks the primary-selected row so a keyboard-opened context menu can
  /// anchor to it even though no cursor position exists.
  final GlobalKey _selectedRowKey = GlobalKey();

  /// The details region, so Enter on a commit row can move focus into it —
  /// the details already follow the selection, so "open" would be a no-op
  /// and moving the keyboard there is what gives Enter a job.
  final GlobalKey<BaseFocusRegionState> _detailsRegionKey =
      GlobalKey<BaseFocusRegionState>();

  /// The commit list's keyboard semantics, in delegated mode: the selection
  /// lives in [commitSelectionProvider] — where clicks, context clicks and
  /// actions already coordinate — so the controller stores no index of its
  /// own. Every read resolves the provider against the displayed commits and
  /// every move writes a single selection back, keeping keyboard and mouse
  /// on the one selection model instead of two that can disagree.
  late final ItemNavigationController _listController;

  /// What the list is currently showing (the filtered window, or deep-search
  /// results), refreshed on every build of the commit history: the delegated
  /// callbacks resolve against exactly what the user sees.
  List<GitCommit> _displayedCommits = const [];
  bool _deepMode = false;

  @override
  void initState() {
    super.initState();
    _listController = ItemNavigationController(
      onActivate: (_) => _detailsRegionKey.currentState?.focusFirstChild(),
      onTrailingBoundary: _loadNextPageAtEdge,
      readIndex: _readSelectedIndex,
      writeIndex: _writeSelectedIndex,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  int _readSelectedIndex() {
    // Resolved, not raw: a stale selection the screen no longer shows must
    // not count as a highlight while the view says nothing is selected.
    final primary = ref
        .read(commitSelectionProvider)
        .resolve(_displayedCommits)
        .primary;
    if (primary == null) return -1;
    return _displayedCommits.indexWhere((c) => c.hash == primary.hash);
  }

  void _writeSelectedIndex(int index) {
    final notifier = ref.read(commitSelectionProvider.notifier);
    if (index < 0 || index >= _displayedCommits.length) {
      notifier.clear();
      return;
    }
    notifier.selectSingle(_displayedCommits[index].hash);
  }

  /// Pushing down or End past the last loaded row asks for the next page:
  /// the keyboard's equivalent of reaching the footer and pressing Load
  /// more. Deep results are a complete answer, so they have no next page.
  void _loadNextPageAtEdge() {
    if (_deepMode) return;
    final window = ref.read(commitWindowProvider).value;
    if (window == null || !window.hasMore || window.isLoadingMore) return;
    unawaited(ref.read(commitWindowProvider.notifier).loadMore());
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

  /// The "clear the search" rung of the Escape ladder, and what the clear
  /// chips do: text, pending debounce and applied filter go together, so the
  /// field can never look empty while the list is still filtered.
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(historySearchFilterProvider.notifier).state =
        const HistorySearchFilter.empty();
    setState(() {});
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

  /// Shift+F10 and the dedicated menu key open the same menu a right-click
  /// does, anchored to the selected row. The menu itself is arrow-key
  /// navigable, which is what makes every entry reachable without a mouse.
  void _openContextMenuFromKeyboard(List<GitCommit> commits) {
    if (ref.read(commitSelectionProvider).resolve(commits).isEmpty) return;
    unawaited(_showCommitContextMenu(commits, _selectedRowMenuPosition()));
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

    // The Escape ladder, innermost rung first: collapse the expanded speed
    // dial, then clear the search text, then leave deep-search mode, then
    // nothing. Each rung is a scope on the key-bubbling path, so the first
    // enabled one consumes the press and the rest wait for the next. When
    // the search field itself holds focus its own watcher clears the text
    // before any of these — correcting a typo stays a field-local gesture.
    // Clearing the text also empties the applied filter, which resets deep
    // search as a consequence: the results answered that exact filter.
    final deepSearchActive = ref.watch(historyDeepSearchProvider).isActive;

    return BaseDismissScope(
      enabled: deepSearchActive,
      onDismiss: () => ref.read(historyDeepSearchProvider.notifier).clear(),
      child: BaseDismissScope(
        enabled: _searchController.text.isNotEmpty,
        onDismiss: _clearSearch,
        child: BaseDismissScope(
          enabled: _fabIsExpanded,
          onDismiss: _collapseFAB,
          child: Scaffold(
            appBar: StandardAppBar(
              title: AppDestination.history.label(context),
              onRefresh: () => ref.invalidate(commitHistoryProvider),
              moreMenuItems: const [],
            ),
            // One ordered traversal root for the screen's regions: search,
            // list, details, diff, action dial. Nested inside the shell's
            // content region, the host orders Tab but leaves F6 and the
            // focus of last resort to the shell.
            body: BaseFocusRegionHost(
              debugLabel: 'HistoryScreen.regions',
              // The screen holds its regions off the window's edge at the
              // generous distance every screen uses: `Inset.roomy`.
              child: BaseInset(
                all: Inset.roomy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BaseFocusRegion(
                      order: 1,
                      debugLabel: 'HistoryScreen.searchRegion',
                      child: _buildSearchBar(context, searchFilter),
                    ),

                    // Main content
                    Expanded(
                      child: _buildMainContent(
                        context,
                        filteredCommitsAsync,
                        searchFilter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Search bar and filters — the screen's first focus region.
  Widget _buildSearchBar(
    BuildContext context,
    HistorySearchFilter searchFilter,
  ) {
    return Container(
      // The band's fill and its rule stay: they are the surface.
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: BaseInset(
        child: Column(
          children: [
            // Search bar row
            Row(
              children: [
                Expanded(
                  // Arrows typed in the field move the commit list's highlight
                  // while the caret stays put, so narrowing and choosing a
                  // commit is one keyboard flow.
                  child: SearchFieldHandoff(
                    controller: _listController,
                    child: BaseTextField(
                      controller: _searchController,
                      hintText: AppLocalizations.of(
                        context,
                      )!.hintTextSearchCommits,
                      prefixIcon: IconRole.magnifyingGlass,
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
                ),
                const BaseGap(Proximity.grouped),
                // Advanced search button
                BaseIconButton(
                  icon: IconRole.faders,
                  tooltip: AppLocalizations.of(context)!.advancedSearch,
                  onPressed: () => _showAdvancedSearch(context),
                  variant: ButtonVariant.primary,
                ),
              ],
            ),
            const BaseGap(Proximity.related),

            // Quick filter chips
            Row(
              children: [
                // The label's own mark: dense, and secondary to the words it
                // introduces.
                const BaseIcon(
                  IconRole.funnel,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.related),
                BaseLabel(
                  AppLocalizations.of(context)!.quickFilters,
                  role: TextRole.detail,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.related),
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
                          onPressed: _clearSearch,
                        ),
                    ],
                  ),
                ),
              ],
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

  /// Chooses between deep-search mode and the ordinary windowed view.
  ///
  /// Deep search replaces the *display* only: the window, the filter and the
  /// selection machinery underneath stay untouched, so leaving the mode
  /// restores exactly what the user had.
  Widget _buildMainContent(
    BuildContext context,
    AsyncValue<List<GitCommit>> filteredCommitsAsync,
    HistorySearchFilter searchFilter,
  ) {
    final deepSearch = ref.watch(historyDeepSearchProvider);
    switch (deepSearch.status) {
      case DeepSearchStatus.running:
        return DeepSearchRunningState(
          onCancel: () => ref.read(historyDeepSearchProvider.notifier).clear(),
        );
      case DeepSearchStatus.failed:
        return DeepSearchFailedState(
          error: deepSearch.error ?? '',
          onBack: () => ref.read(historyDeepSearchProvider.notifier).clear(),
        );
      case DeepSearchStatus.results:
        return Column(
          children: [
            DeepSearchResultsBanner(
              matchCount: deepSearch.results.length,
              capped: deepSearch.capped,
              cappedLimit: AppConstants.deepSearchResultLimit,
              onBack: () =>
                  ref.read(historyDeepSearchProvider.notifier).clear(),
              onSearchChanges:
                  (!deepSearch.pickaxe &&
                      (deepSearch.filter?.query?.isNotEmpty ?? false))
                  ? () => _startDeepSearch(pickaxe: true)
                  : null,
            ),
            Expanded(
              child: deepSearch.results.isEmpty
                  ? const DeepSearchNoResultsState()
                  : _buildCommitHistory(
                      context,
                      deepSearch.results,
                      deepMode: true,
                    ),
            ),
          ],
        );
      case DeepSearchStatus.idle:
        return filteredCommitsAsync.when(
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
        );
    }
  }

  /// Runs the whole-history search for the filter currently in effect.
  void _startDeepSearch({bool pickaxe = false}) {
    final filter = ref.read(historySearchFilterProvider);
    unawaited(
      ref
          .read(historyDeepSearchProvider.notifier)
          .run(filter, pickaxe: pickaxe),
    );
  }

  Widget _buildCommitHistory(
    BuildContext context,
    List<GitCommit> commits, {
    bool deepMode = false,
  }) {
    // Keep the delegated controller resolving against exactly what this
    // build displays — the windowed view or deep results — before any key
    // event can arrive for it.
    _displayedCommits = commits;
    _deepMode = deepMode;
    if (!deepMode && commits.isNotEmpty) {
      // Highlight the newest commit once the frame is built, so the details
      // follow immediately and "N arrows then Enter" counts from the first
      // row. Deep results deliberately keep the selection the user had: the
      // mode must restore exactly that state when it is left.
      _listController.scheduleInitialHighlight();
    }

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
    final window = ref.watch(commitWindowProvider).value;
    final loadedCount = window?.commits.length ?? commits.length;

    // Lanes are positions in the exact row sequence the graph pass walked.
    // The in-memory filter only ever removes rows, so an unchanged length
    // means the displayed list is the window itself; anything narrower falls
    // back to the plain dot instead of drawing lanes to missing neighbors.
    // Deep results are scattered matches, not the window, so lanes would lie.
    final graph = !deepMode && commits.length == loadedCount
        ? ref.watch(commitGraphProvider).value
        : null;

    // Build FAB actions based on selection
    final fabActions = <SpeedDialAction>[
      // Squash Commits (requires 2+ commits)
      if (selectedCount >= 2)
        SpeedDialAction(
          icon: PhosphorIconsRegular.arrowsInLineVertical,
          label: l10n.squashCommits,
          onPressed: () => _showSquashDialog(context, selection),
        ),
      // Cherry-pick (requires 1+ commits)
      if (selectedCount > 0)
        SpeedDialAction(
          icon: PhosphorIconsRegular.arrowBendDownRight,
          label: l10n.cherryPick,
          onPressed: () => _performCherryPick(context, selection),
        ),
      // Revert (requires exactly 1 commit)
      if (selectedCount == 1)
        SpeedDialAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.revert,
          onPressed: () => _performRevert(context, selection),
        ),
      // Reset to Here (requires exactly 1 commit)
      if (selectedCount == 1)
        SpeedDialAction(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: l10n.resetToHere,
          onPressed: () => _performReset(context, selection),
        ),
      // Create Tag (requires exactly 1 commit)
      if (selectedCount == 1)
        SpeedDialAction(
          icon: PhosphorIconsRegular.tag,
          label: l10n.createTag,
          onPressed: () {
            final commit = selection.single;
            if (commit == null) return;
            _showCreateTagDialog(context, commit);
          },
        ),
    ];

    // The three columns as focus regions on the screen's ordered Tab walk:
    // list (2), details (3), diff (4) — the search bar above is 1 and the
    // speed dial below is 5. Key handling lives on the list's own focus
    // node inside the navigable view, never on a wrapper spanning the
    // sibling panels, so a focused control in the details or diff column
    // keeps its arrow keys.
    final contentWidget = Row(
      children: [
        // Commit list (left side)
        Expanded(
          flex: 2,
          child: BaseFocusRegion(
            order: 2,
            debugLabel: 'HistoryScreen.listRegion',
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: BaseInset(
                      all: Inset.roomy,
                      child: Row(
                        children: [
                          const BaseIcon(
                            IconRole.listBullets,
                            scale: ControlScale.compact,
                            tone: Tone.accent,
                          ),
                          const BaseGap(Proximity.related),
                          BaseLabel(
                            searchFilter.isNotEmpty
                                ? l10n.commitsMatchedOfLoaded(
                                    commits.length,
                                    loadedCount,
                                  )
                                : l10n.commitsCount(commits.length),
                            role: TextRole.sectionTitle,
                          ),
                          if (!deepMode &&
                              searchFilter.isNotEmpty &&
                              searchFilter.supportsDeepSearch &&
                              (window?.hasMore ?? false)) ...[
                            const Spacer(),
                            BaseButton(
                              label: l10n.historySearchAllHistory,
                              variant: ButtonVariant.tertiary,
                              size: ButtonSize.small,
                              leadingIcon: IconRole.listMagnifyingGlass,
                              onPressed: () => _startDeepSearch(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Commit list
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final currentBranch = ref
                            .watch(currentBranchProvider)
                            .value;

                        // The footer is the trailing row and the one place
                        // that says whether the list ends because the
                        // history does or the loaded window does. Its
                        // keyboard equivalent is the trailing boundary:
                        // pushing past the last row pages through the same
                        // loadMore the button invokes.
                        final footer =
                            (!deepMode && window != null && window.canExtend)
                            ? HistoryListFooter(
                                loadedCount: loadedCount,
                                hasMore: window.hasMore,
                                isLoadingMore: window.isLoadingMore,
                                loadMoreError: window.loadMoreError,
                                pageSize: ref.read(defaultCommitLimitProvider),
                                searchActive: searchFilter.isNotEmpty,
                                onLoadMore: () => unawaited(
                                  ref
                                      .read(commitWindowProvider.notifier)
                                      .loadMore(),
                                ),
                                onSearchAllHistory:
                                    searchFilter.supportsDeepSearch
                                    ? () => _startDeepSearch()
                                    : null,
                              )
                            : null;
                        return KeyboardNavigableListView(
                          controller: _listController,
                          itemCount: commits.length,
                          autofocus: true,
                          trailing: footer,
                          // Shift+F10 and the dedicated menu key open the
                          // same menu a right-click does, anchored to the
                          // selected row; the menu itself is arrow-key
                          // navigable.
                          additionalBindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.f10,
                              shift: true,
                            ): () =>
                                _openContextMenuFromKeyboard(commits),
                            const SingleActivator(
                              LogicalKeyboardKey.contextMenu,
                            ): () =>
                                _openContextMenuFromKeyboard(commits),
                          },
                          itemBuilder: (context, index, isHighlighted, hasFocus) {
                            final commit = commits[index];

                            return CommitListItem(
                              // The key follows the primary row so the
                              // keyboard path can anchor the context
                              // menu to its on-screen position.
                              key: isHighlighted ? _selectedRowKey : null,
                              commit: commit,
                              isSelected: isHighlighted,
                              isMultiSelected: selectedHashes.contains(
                                commit.hash,
                              ),
                              containerHasFocus: hasFocus,
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
        ),

        // Metadata and changed files share the middle column so the right
        // column can hold the highlighted file's diff in place - seeing a
        // commit's changes no longer requires opening a dialog per file.
        Expanded(
          flex: 2,
          child: BaseFocusRegion(
            key: _detailsRegionKey,
            order: 3,
            debugLabel: 'HistoryScreen.detailsRegion',
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
                        // Two panes of one region: `related`.
                        const BaseGap(Proximity.related),
                        Expanded(
                          child: FileTreePanel(
                            commitHash: selection.primary!.hash,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),

        // The highlighted file's diff (right side)
        Expanded(
          flex: 3,
          child: BaseFocusRegion(
            order: 4,
            debugLabel: 'HistoryScreen.diffRegion',
            child: selection.primary == null
                ? _buildNoCommitSelected(context)
                : CommitDiffPanel(commitHash: selection.primary!.hash),
          ),
        ),
      ],
    );

    // Wrap with Stack and FAB if we have actions
    if (fabActions.isEmpty) {
      // The dial can disappear underneath its expanded flag (the selection
      // was cleared); reset the flag so the ladder's dial rung never eats an
      // Escape for a surface that is no longer on screen.
      if (_fabIsExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _collapseFAB();
        });
      }
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
            // The action dial is the screen's action bar: last region on the
            // Tab walk. Escape while the dial itself holds focus is handled
            // inside it; from anywhere else the dial rung of the screen's
            // dismiss ladder collapses it.
            BaseFocusRegion(
              order: 5,
              debugLabel: 'HistoryScreen.actionsRegion',
              child: BaseSpeedDial(
                actions: fabActions,
                isExpanded: _fabIsExpanded,
                onToggle: _toggleFAB,
                onCollapse: _collapseFAB,
              ),
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
    final searchFilter = ref.read(historySearchFilterProvider);
    final window = ref.watch(commitWindowProvider).value;
    final offerDeepSearch =
        searchFilter.supportsDeepSearch && (window?.hasMore ?? false);
    return NoSearchResultsState(
      onClearFilters: _clearSearch,
      onSearchAllHistory: offerDeepSearch ? () => _startDeepSearch() : null,
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
    // The destructive entries below say what they mean exactly once, as
    // `tone: Tone.danger`. Each of them used to say it twice - the tone for
    // the mark, and a `labelColor:` naming Material's error role for the
    // words - because the tone reached only the glyph. That was the
    // component's gap rather than this screen's, and it is now closed in
    // `lib/shared/components/base_menu_item.dart`: `MenuItemContent` resolves
    // the label from the tone it was already handed, so the three colours
    // here are gone and no pixel with them.
    final count = selection.count;

    return [
      BaseMenuItem(
        value: _CommitContextAction.copySha,
        child: MenuItemContent(icon: IconRole.copy, label: l10n.copySha),
      ),
      BaseMenuItem(
        value: _CommitContextAction.copyMessage,
        child: MenuItemContent(
          icon: IconRole.chatText,
          label: l10n.copyCommitMessage,
        ),
      ),
      if (count == 1) ...[
        BaseMenuItem(
          value: _CommitContextAction.createBranch,
          child: MenuItemContent(
            icon: IconRole.gitBranch,
            label: l10n.createBranchFromCommit,
          ),
        ),
        BaseMenuItem(
          value: _CommitContextAction.createTag,
          child: MenuItemContent(icon: IconRole.tag, label: l10n.createTag),
        ),
      ],
      if (count == 2)
        BaseMenuItem(
          value: _CommitContextAction.compare,
          child: MenuItemContent(
            icon: IconRole.gitDiff,
            label: l10n.compareCommits,
          ),
        ),
      BaseMenuItem(
        value: _CommitContextAction.cherryPick,
        child: MenuItemContent(
          icon: IconRole.arrowBendDownRight,
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
            icon: IconRole.arrowsInLineVertical,
            label: l10n.squashCommits,
            tone: Tone.danger,
          ),
        ),
      if (count == 1) ...[
        BaseMenuItem(
          value: _CommitContextAction.revert,
          child: MenuItemContent(
            icon: IconRole.arrowCounterClockwise,
            label: l10n.revert,
            tone: Tone.danger,
          ),
        ),
        BaseMenuItem(
          value: _CommitContextAction.reset,
          child: MenuItemContent(
            icon: IconRole.arrowCounterClockwise,
            label: l10n.resetToHere,
            tone: Tone.danger,
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
    // The shared dialog validates its form, creates the tag through the
    // actions layer and refreshes the tag providers itself; the commit only
    // preselects the dialog's target revision.
    await showCreateTagDialog(context, initialCommit: commit.hash);
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
    final confirmed = await confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.cherryPick,
      title: l10n.cherryPickConfirmTitle,
      message: l10n.cherryPickConfirmMessage(ordered.length),
      confirmLabel: l10n.cherryPick,
    );
    if (!confirmed || !context.mounted) return;

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
    final confirmed = await confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.revert,
      title: l10n.revertCommitConfirmTitle,
      message: l10n.revertCommitConfirmMessage(commit.shortHash),
      confirmLabel: l10n.revert,
    );
    if (!confirmed || !context.mounted) return;

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

    // Force push overwrites remote history and can destroy work that is not
    // the user's own: the strongest tier. The gate only enables once the
    // user has retyped the upstream ref that is about to be overwritten.
    final shouldForcePush = await confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.forcePush,
      icon: IconRole.warningCircle,
      title: l10n.forcePush,
      message:
          '${l10n.forcePushConfirmMessage(upstream)}\n\n'
          '• ${l10n.forcePushOnlyIfAlone}\n'
          '• ${l10n.forcePushOthersNeedReset}\n'
          '• ${l10n.forcePushCannotBeEasilyUndone}',
      confirmLabel: l10n.forcePush,
      confirmationToken: upstream,
    );

    if (!shouldForcePush || !context.mounted) return;

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
