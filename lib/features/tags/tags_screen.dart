import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/base_dismiss_scope.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../shared/components/base_animated_widgets.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/dialogs/confirm_destructive.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/destructive_action.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/tag.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/utils/result_extensions.dart';
import 'dialogs/advanced_filters_dialog.dart'
    show AdvancedFiltersDialog, DateRangeFilter;
import 'dialogs/delete_tags_dialog.dart';
import 'dialogs/select_remote_dialog.dart';
import 'widgets/tag_list_tile.dart';
import 'widgets/tag_sync_banner.dart';
import 'widgets/tag_filter_chips.dart';
import 'widgets/tags_no_repository_state.dart';
import 'widgets/tags_error_state.dart';
import 'widgets/tags_empty_state.dart';
import 'widgets/tags_active_filters.dart';
import 'widgets/tags_batch_operations_bar.dart';
import 'services/tags_service.dart';

/// Tags screen - Tag management
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _tagsService = const TagsService();
  final _searchController = TextEditingController();
  late final ItemNavigationController _listController;

  String _searchQuery = '';
  TagFilterType _filterType = TagFilterType.all;
  bool _selectionMode = false;
  final Set<String> _selectedTags = {};

  /// The tags the flat list currently shows, in list order, so the keyboard
  /// activation resolves an index against exactly what the user sees. Empty
  /// while the grouped view is in front — the keyboard drives the flat list
  /// only.
  List<GitTag> _visibleTags = const [];

  /// One expansion state per tag, owned here so Enter on the highlighted row
  /// can open and close its details. Keyed by the tag name; the controller
  /// holds the expanded flag itself, so it also survives the row scrolling
  /// out of the list's build window.
  final Map<String, ExpansibleController> _expansionControllers = {};

  // Advanced filters
  DateRangeFilter _dateFilter = DateRangeFilter.all;
  DateTime? _customDateStart;
  DateTime? _customDateEnd;
  String? _authorFilter;
  bool _useRegex = false;

  // Sorting
  TagSortBy _sortBy = TagSortBy.dateNewest;

  // Grouping
  TagGroupBy _groupBy = TagGroupBy.none;

  @override
  void initState() {
    super.initState();
    _listController = ItemNavigationController(onActivate: _activateTagAt);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    for (final controller in _expansionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ExpansibleController _expansionControllerFor(String tagName) {
    return _expansionControllers.putIfAbsent(tagName, ExpansibleController.new);
  }

  /// The keyboard activation of a tag row, mirroring what a click does:
  /// toggle the tag's checkmark in selection mode, its details otherwise.
  void _activateTagAt(int index) {
    if (index < 0 || index >= _visibleTags.length) return;
    final tag = _visibleTags[index];
    if (_selectionMode) {
      setState(() {
        if (!_selectedTags.remove(tag.name)) {
          _selectedTags.add(tag.name);
        }
      });
      return;
    }
    final controller = _expansionControllerFor(tag.name);
    if (controller.isExpanded) {
      controller.collapse();
    } else {
      controller.expand();
    }
  }

  /// Leaves the keyboard nothing to resolve while no flat list is built.
  ///
  /// Building the flat list is what keeps [_visibleTags] and the controller's
  /// item count in step with what the user sees, so every state that replaces
  /// that list — no tags at all, nothing matching the search, the grouped view
  /// — has to clear both by hand. Without it the previous list stays
  /// addressable and Enter activates a row that is no longer on screen:
  /// silently expanding a hidden tag, or checking one in selection mode.
  void _detachKeyboardNavigation() {
    _visibleTags = const [];
    _listController.itemCount = 0;
  }

  /// The Escape rung for the search text; also what the field's X does.
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  /// Enters the multi-select mode, the way the overflow menu's entry does.
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
    });
    _reclaimListFocus();
  }

  /// The Escape rung for the selection mode; also what the app bar's X does.
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTags.clear();
    });
    _reclaimListFocus();
  }

  /// Puts the keyboard back on the tag list after the selection mode toggled.
  ///
  /// Both switches replace the whole app bar, so the control that operated
  /// them — the overflow menu's entry, the mode's X button — is unmounted with
  /// it and has no focus to hand back. Focus then falls to the enclosing route
  /// scope and the screen goes keyboard-dead until the user tabs back in. The
  /// list is the screen's one navigable stop, so it is where the keyboard
  /// belongs; the request is deferred because the new app bar has not been
  /// built yet at the moment the mode flips.
  void _reclaimListFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listController.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final localOnlyTags = ref.watch(localOnlyTagsProvider).value ?? {};
    final remoteOnlyTags = ref.watch(remoteOnlyTagsProvider).value ?? {};
    final remotes = ref.watch(remoteNamesProvider).value ?? [];

    if (repositoryPath == null) {
      return _buildNoRepository(context);
    }

    // The Escape ladder, innermost rung first: clear the search text, then
    // leave the selection mode, then nothing — a disabled scope is
    // transparent, so Escape is dead when neither is active. A filled field
    // that holds focus still clears itself before either rung (its own
    // watcher sits closer to the caret); the search rung here is what makes
    // Escape clear the filter from the list too, where the keyboard actually
    // lives, exactly as on the browse and history screens.
    return BaseDismissScope(
      enabled: _selectionMode,
      onDismiss: _exitSelectionMode,
      child: BaseDismissScope(
        enabled: _searchQuery.isNotEmpty,
        onDismiss: _clearSearch,
        child: Scaffold(
          appBar: _selectionMode
              ? AppBar(
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.selectedCount(_selectedTags.length),
                  ),
                  leading: BaseIconButton(
                    icon: IconRole.x,
                    tooltip: AppLocalizations.of(context)!.exitSelection,
                    onPressed: _exitSelectionMode,
                  ),
                  actions: [
                    BaseIconButton(
                      icon: IconRole.checkSquareOffset,
                      tooltip: AppLocalizations.of(context)!.selectAll,
                      onPressed: () => _selectAllTags(tagsAsync.value ?? []),
                    ),
                    BaseIconButton(
                      icon: IconRole.square,
                      tooltip: AppLocalizations.of(context)!.clearSelection,
                      onPressed: () {
                        setState(() {
                          _selectedTags.clear();
                        });
                      },
                    ),
                  ],
                )
              : StandardAppBar(
                  title: AppDestination.tags.label(context),
                  onRefresh: () => ref.read(gitActionsProvider).refreshTags(),
                  moreMenuItems: [
                    // Select Tags action (only show if tags exist)
                    if (tagsAsync.value?.isNotEmpty == true)
                      PopupMenuItem(
                        onTap: _enterSelectionMode,
                        child: MenuItemContent(
                          icon: IconRole.checkSquare,
                          label: AppLocalizations.of(context)!.selectTags,
                        ),
                      ),
                    // Fetch Tags action
                    if (tagsAsync.value?.isNotEmpty == true)
                      const PopupMenuDivider(),
                    PopupMenuItem(
                      child: MenuItemContent(
                        icon: IconRole.downloadSimple,
                        label: AppLocalizations.of(context)!.fetchTags,
                      ),
                      onTap: () => _fetchTags(context),
                    ),
                  ],
                ),
          body: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: tagsAsync.when(
                    data: (tags) => _buildTagList(
                      context,
                      tags,
                      localOnlyTags,
                      remoteOnlyTags,
                      remotes,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => _buildError(context, error),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _selectionMode && _selectedTags.isNotEmpty
              ? _buildBatchOperationsBar(context)
              : null,
        ),
      ),
    );
  }

  Widget _buildNoRepository(BuildContext context) {
    return const TagsNoRepositoryState();
  }

  Widget _buildError(BuildContext context, Object error) {
    return TagsErrorState(error: error);
  }

  Widget _buildTagList(
    BuildContext context,
    List<GitTag> tags,
    Set<String> localOnlyTags,
    Set<String> remoteOnlyTags,
    List<String> remotes,
  ) {
    if (tags.isEmpty) {
      return _buildEmptyState(context);
    }

    // Filter and sort tags using the service
    final filteredAndSortedTags = _tagsService.sortTags(
      tags: _tagsService.filterTags(
        tags: tags,
        filterType: _filterType,
        searchQuery: _searchQuery,
        useRegex: _useRegex,
        dateFilter: _dateFilter,
        customDateStart: _customDateStart,
        customDateEnd: _customDateEnd,
        authorFilter: _authorFilter,
      ),
      sortBy: _sortBy,
    );

    // Chip counts must stay independent of the type filter itself. Derived
    // from the type-filtered list, the unselected chips read 0 and the user
    // concludes those tags do not exist.
    final typeFilterCandidates = _tagsService.filterTags(
      tags: tags,
      filterType: TagFilterType.all,
      searchQuery: _searchQuery,
      useRegex: _useRegex,
      dateFilter: _dateFilter,
      customDateStart: _customDateStart,
      customDateEnd: _customDateEnd,
      authorFilter: _authorFilter,
    );

    return Column(
      children: [
        // Sync status notification
        TagSyncBanner(
          localOnlyCount: localOnlyTags.length,
          remoteOnlyCount: remoteOnlyTags.length,
          onPushAll: () => _pushAllTags(context),
          onFetchAll: () => _fetchTags(context),
        ),

        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InlineSearchField(
                      controller: _searchController,
                      hintText: _useRegex
                          ? 'Regex search...'
                          : 'Search tags...',
                      // Arrows hand off to the flat list while typing
                      // continues in the field; the grouped view is browsed
                      // with the pointer, so no handoff there.
                      navigationController: _groupBy == TagGroupBy.none
                          ? _listController
                          : null,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BaseIconButton(
                    // One role, one mark; "the filter is engaged" travels
                    // as `isSelected` and the skin decides the weight.
                    icon: IconRole.funnel,
                    isSelected: _hasActiveFilters(),
                    tooltip: AppLocalizations.of(context)!.advancedFilters,
                    onPressed: () => _showAdvancedFiltersDialog(context, tags),
                    variant: ButtonVariant.secondary,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BasePopupMenuButton<TagSortBy>(
                    icon: const Icon(PhosphorIconsRegular.sortAscending),
                    tooltip: AppLocalizations.of(context)!.sortTags,
                    onSelected: (sortBy) {
                      setState(() {
                        _sortBy = sortBy;
                      });
                    },
                    itemBuilder: (context) => <PopupMenuEntry<TagSortBy>>[
                      PopupMenuItem(
                        value: TagSortBy.nameAsc,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.nameAsc
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.sortNameAZ,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortAscending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagSortBy.nameDesc,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.nameDesc
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.sortNameZA,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortDescending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: TagSortBy.dateNewest,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.dateNewest
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.sortDateNewest,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortDescending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagSortBy.dateOldest,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.dateOldest
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.sortDateOldest,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortAscending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: TagSortBy.versionAsc,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.versionAsc
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(
                                  context,
                                )!.sortVersionLowHigh,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortAscending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagSortBy.versionDesc,
                        child: Row(
                          children: [
                            Icon(
                              _sortBy == TagSortBy.versionDesc
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(
                                  context,
                                )!.sortVersionHighLow,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.sortDescending,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BasePopupMenuButton<TagGroupBy>(
                    icon: Icon(
                      _groupBy != TagGroupBy.none
                          ? PhosphorIconsFill.rows
                          : PhosphorIconsRegular.rows,
                      color: _groupBy != TagGroupBy.none
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: AppLocalizations.of(context)!.groupTags,
                    onSelected: (groupBy) {
                      setState(() {
                        _groupBy = groupBy;
                      });
                    },
                    itemBuilder: (context) => <PopupMenuEntry<TagGroupBy>>[
                      PopupMenuItem(
                        value: TagGroupBy.none,
                        child: Row(
                          children: [
                            Icon(
                              _groupBy == TagGroupBy.none
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.noGrouping,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: TagGroupBy.prefix,
                        child: Row(
                          children: [
                            Icon(
                              _groupBy == TagGroupBy.prefix
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.byPrefix,
                              ),
                            ),
                            const Icon(PhosphorIconsRegular.textAa, size: 16),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagGroupBy.version,
                        child: Row(
                          children: [
                            Icon(
                              _groupBy == TagGroupBy.version
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.byVersion,
                              ),
                            ),
                            const Icon(
                              PhosphorIconsRegular.gitBranch,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagGroupBy.author,
                        child: Row(
                          children: [
                            Icon(
                              _groupBy == TagGroupBy.author
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.byAuthor,
                              ),
                            ),
                            const Icon(PhosphorIconsRegular.user, size: 16),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TagGroupBy.date,
                        child: Row(
                          children: [
                            Icon(
                              _groupBy == TagGroupBy.date
                                  ? PhosphorIconsBold.checkCircle
                                  : PhosphorIconsRegular.circle,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Expanded(
                              child: BodyMediumLabel(
                                AppLocalizations.of(context)!.byDate,
                              ),
                            ),
                            const Icon(PhosphorIconsRegular.calendar, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_hasActiveFilters()) ...[
                const SizedBox(height: AppTheme.paddingS),
                _buildActiveFiltersRow(),
              ],
              const SizedBox(height: AppTheme.paddingS),
              // Filter chips
              TagFilterChips(
                allTags: typeFilterCandidates,
                selectedFilter: _filterType,
                onFilterChanged: (filterType) {
                  setState(() {
                    _filterType = filterType;
                  });
                },
              ),
            ],
          ),
        ),

        // Tag count header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingM,
            vertical: AppTheme.paddingS,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.tag, size: AppTheme.iconS),
              const SizedBox(width: AppTheme.paddingS),
              TitleSmallLabel(
                '${filteredAndSortedTags.length} ${filteredAndSortedTags.length == 1 ? 'Tag' : 'Tags'}',
              ),
              if (_searchQuery.isNotEmpty ||
                  _filterType != TagFilterType.all) ...[
                const SizedBox(width: AppTheme.paddingS),
                BodySmallLabel(
                  AppLocalizations.of(context)!.ofTotal(tags.length),
                ),
              ],
              const Spacer(),
              if (localOnlyTags.isNotEmpty)
                BaseButton(
                  label: AppLocalizations.of(
                    context,
                  )!.pushCount(localOnlyTags.length),
                  variant: ButtonVariant.secondary,
                  leadingIcon: IconRole.upload,
                  onPressed: () => _pushAllTags(context),
                ),
            ],
          ),
        ),

        // Tag list
        Expanded(
          child: filteredAndSortedTags.isEmpty
              ? _buildNoMatchState()
              : _buildGroupedTagList(
                  filteredAndSortedTags,
                  localOnlyTags,
                  remotes,
                ),
        ),
      ],
    );
  }

  /// Shown when the filters and the search leave no tag standing.
  Widget _buildNoMatchState() {
    _detachKeyboardNavigation();
    return Center(child: BodyLargeLabel('No tags match your search'));
  }

  /// Build grouped tag list with collapsible group headers
  Widget _buildGroupedTagList(
    List<GitTag> tags,
    Set<String> localOnlyTags,
    List<String> remotes,
  ) {
    final groupedTags = _tagsService.groupTags(tags: tags, groupBy: _groupBy);

    if (_groupBy == TagGroupBy.none) {
      _visibleTags = tags;
      _listController.scheduleInitialHighlight();

      // No grouping - one Tab stop with a roving highlight; Enter toggles
      // the highlighted tag's details, or its checkmark in selection mode.
      return KeyboardNavigableListView(
        controller: _listController,
        itemCount: tags.length,
        autofocus: true,
        itemBuilder: (context, index, isHighlighted, containerHasFocus) {
          final tag = tags[index];
          return TagListTile(
            tag: tag,
            selectionMode: _selectionMode,
            isSelected: _selectedTags.contains(tag.name),
            isHighlighted: isHighlighted,
            containerHasFocus: containerHasFocus,
            isLocalOnly: localOnlyTags.contains(tag.name),
            hasRemotes: remotes.isNotEmpty,
            expansionController: _expansionControllerFor(tag.name),
            // A pointer toggle moves the highlight to the row it acted on,
            // so keyboard and mouse stay in one story.
            onExpansionChanged: (_) => _listController.select(index),
            onSelectionChanged: (selected) {
              _listController.select(index);
              setState(() {
                if (selected) {
                  _selectedTags.add(tag.name);
                } else {
                  _selectedTags.remove(tag.name);
                }
              });
            },
          );
        },
      );
    }

    // Grouped view with collapsible sections; the keyboard drives the flat
    // list only, so nothing is activatable while a grouping is applied.
    _detachKeyboardNavigation();
    return ListView.builder(
      itemCount: groupedTags.length,
      itemBuilder: (context, groupIndex) {
        final groupEntry = groupedTags.entries.elementAt(groupIndex);
        final groupName = groupEntry.key;
        final groupTags = groupEntry.value;

        return ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(
            PhosphorIconsBold.folder,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: TitleMediumLabel(groupName),
          subtitle: BodySmallLabel(
            '${groupTags.length} ${groupTags.length == 1 ? 'tag' : 'tags'}',
          ),
          children: groupTags.map((tag) {
            return TagListTile(
              tag: tag,
              selectionMode: _selectionMode,
              isSelected: _selectedTags.contains(tag.name),
              isLocalOnly: localOnlyTags.contains(tag.name),
              hasRemotes: remotes.isNotEmpty,
              onSelectionChanged: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag.name);
                  } else {
                    _selectedTags.remove(tag.name);
                  }
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    _detachKeyboardNavigation();
    return const TagsEmptyState();
  }

  void _selectAllTags(List<GitTag> tags) {
    setState(() {
      // Use the very same filter the list view uses. A reimplementation here
      // only honoured the type filter and a plain substring search, so
      // 'Select All' selected tags hidden by the active date, author or regex
      // filters -- and a batch delete then removed tags the user never saw.
      final visible = _tagsService.filterTags(
        tags: tags,
        filterType: _filterType,
        searchQuery: _searchQuery,
        useRegex: _useRegex,
        dateFilter: _dateFilter,
        customDateStart: _customDateStart,
        customDateEnd: _customDateEnd,
        authorFilter: _authorFilter,
      );

      _selectedTags.addAll(visible.map((tag) => tag.name));
    });
  }

  bool _hasActiveFilters() {
    return _dateFilter != DateRangeFilter.all ||
        (_authorFilter != null && _authorFilter!.isNotEmpty) ||
        _useRegex;
  }

  Widget _buildActiveFiltersRow() {
    return TagsActiveFilters(
      dateFilter: _dateFilter,
      authorFilter: _authorFilter,
      useRegex: _useRegex,
      onClearDateFilter: () {
        setState(() {
          _dateFilter = DateRangeFilter.all;
          _customDateStart = null;
          _customDateEnd = null;
        });
      },
      onClearAuthorFilter: () {
        setState(() {
          _authorFilter = null;
        });
      },
      onClearRegexFilter: () {
        setState(() {
          _useRegex = false;
        });
      },
      onClearAllFilters: () {
        setState(() {
          _dateFilter = DateRangeFilter.all;
          _customDateStart = null;
          _customDateEnd = null;
          _authorFilter = null;
          _useRegex = false;
        });
      },
      tagsService: _tagsService,
    );
  }

  Widget _buildBatchOperationsBar(BuildContext context) {
    return TagsBatchOperationsBar(
      selectedCount: _selectedTags.length,
      onPush: () => _pushSelectedTags(context),
      onDelete: () => _deleteSelectedTags(context),
    );
  }

  Future<void> _showAdvancedFiltersDialog(
    BuildContext context,
    List<GitTag> allTags,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AdvancedFiltersDialog(
        allTags: allTags,
        initialDateFilter: _dateFilter,
        initialCustomDateStart: _customDateStart,
        initialCustomDateEnd: _customDateEnd,
        initialAuthorFilter: _authorFilter,
        initialUseRegex: _useRegex,
      ),
    );

    if (result != null) {
      setState(() {
        if (result['reset'] == true) {
          // Reset all filters
          _dateFilter = DateRangeFilter.all;
          _customDateStart = null;
          _customDateEnd = null;
          _authorFilter = null;
          _useRegex = false;
        } else {
          // Apply new filters
          _dateFilter = result['dateFilter'] as DateRangeFilter;
          _customDateStart = result['customDateStart'] as DateTime?;
          _customDateEnd = result['customDateEnd'] as DateTime?;
          _authorFilter = result['authorFilter'] as String?;
          _useRegex = result['useRegex'] as bool;
        }
      });
    }
  }

  Future<void> _fetchTags(BuildContext context) async {
    await ref.read(gitActionsProvider).fetchTags();
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      context.showSuccessIfMounted(l10n.snackbarTagsFetched);
    }
  }

  Future<void> _pushAllTags(BuildContext context) async {
    final remotes = await ref.read(remoteNamesProvider.future);

    if (remotes.isEmpty) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        context.showErrorIfMounted(l10n.snackbarNoRemotesConfigured);
      }
      return;
    }

    if (context.mounted) {
      final remoteName = remotes.length == 1
          ? remotes.first
          : await showDialog<String>(
              context: context,
              builder: (context) => SelectRemoteDialog(remotes: remotes),
            );

      if (remoteName != null && context.mounted) {
        await ref.read(gitActionsProvider).pushAllTags(remoteName);
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          context.showSuccessIfMounted(l10n.snackbarAllTagsPushed(remoteName));
        }
      }
    }
  }

  Future<void> _pushSelectedTags(BuildContext context) async {
    if (_selectedTags.isEmpty) return;

    final remotes = await ref.read(remoteNamesProvider.future);

    if (remotes.isEmpty) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        context.showErrorIfMounted(l10n.snackbarNoRemotesConfigured);
      }
      return;
    }

    if (context.mounted) {
      final remoteName = remotes.length == 1
          ? remotes.first
          : await showDialog<String>(
              context: context,
              builder: (context) => SelectRemoteDialog(remotes: remotes),
            );

      if (remoteName != null && context.mounted) {
        // Use batch operation to push all selected tags at once
        await ref
            .read(gitActionsProvider)
            .pushTags(remoteName, _selectedTags.toList());

        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          context.showSuccessIfMounted(
            l10n.snackbarTagsPushed(_selectedTags.length, remoteName),
          );
          setState(() {
            _selectionMode = false;
            _selectedTags.clear();
          });
        }
      }
    }
  }

  Future<void> _deleteSelectedTags(BuildContext context) async {
    if (_selectedTags.isEmpty) return;

    // Check if we have remotes
    final remotes = await ref.read(remoteNamesProvider.future);
    final hasRemotes = remotes.isNotEmpty;

    if (!context.mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          DeleteTagsDialog(tagNames: _selectedTags, hasRemotes: hasRemotes),
    );

    if (result != null && result['confirmed'] == true && context.mounted) {
      final deleteFromRemote = result['deleteFromRemote'] == true;

      // Get remote name if deleting from remote
      String? remoteName;
      if (deleteFromRemote && hasRemotes) {
        // Deleting tags off a server is destructive, so the target remote is
        // picked explicitly instead of guessed, just like the push flows.
        remoteName = remotes.length == 1
            ? remotes.first
            : await showDialog<String>(
                context: context,
                builder: (context) => SelectRemoteDialog(remotes: remotes),
              );
        if (remoteName == null || !context.mounted) return;

        // The remote leg is remote-permanent: it always confirms, and the
        // gate only enables once the user has typed the remote's name. The
        // remote is the token because no single tag identifies a bulk
        // delete — the one name every removed ref shares is where the
        // shared, irreversible loss happens.
        final l10n = AppLocalizations.of(context)!;
        final confirmed = await confirmDestructive(
          context: context,
          ref: ref,
          action: DestructiveAction.deleteRemoteTag,
          icon: IconRole.warningCircle,
          title: l10n.deleteTagsDialog,
          message: l10n.deleteTagsFromRemoteConfirmMessage(
            _selectedTags.length,
            remoteName,
          ),
          confirmLabel: l10n.delete,
          confirmationToken: remoteName,
        );
        if (!confirmed || !context.mounted) return;
      }

      // Use batch operation to delete all selected tags at once
      await ref
          .read(gitActionsProvider)
          .deleteTags(
            _selectedTags.toList(),
            deleteFromRemote: deleteFromRemote,
            remoteName: remoteName,
          );

      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        context.showSuccessIfMounted(
          l10n.snackbarTagsDeleted(_selectedTags.length),
        );
        setState(() {
          _selectionMode = false;
          _selectedTags.clear();
        });
      }
    }
  }
}

/// Tag filter type
enum TagFilterType { all, annotated, lightweight }

/// Tag sorting options
enum TagSortBy {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  versionAsc,
  versionDesc,
}

/// Tag grouping options
enum TagGroupBy { none, prefix, version, author, date }
