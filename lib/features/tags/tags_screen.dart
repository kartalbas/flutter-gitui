import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        ControlScale,
        DialogRouteSpec,
        Emphasis,
        IconRole,
        Inset,
        MenuAnchorSpec,
        MenuChoice,
        MenuEntry,
        MenuSeparator,
        Overlays,
        Proximity,
        ScreenSpec,
        SelectionBarSpec,
        Skin,
        SkinScope,
        TextRole,
        Tone,
        ToolbarActionEntry,
        ToolbarEntry,
        ToolbarGroup,
        ToolbarMenuEntry;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/widgets/base_dismiss_scope.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/screen_body_host.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../shared/components/base_icon.dart';
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
import 'services/tags_service.dart';
import '../../shared/components/base_layout.dart';

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
    final l10n = AppLocalizations.of(context)!;

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
        child: SkinScope.render(
          context,
          (Skin skin, BuildContext inner) => skin.chrome.screen(
            inner,
            ScreenSpec(
              // What the screen is called, and while things are being picked,
              // what has been picked - the same sentence the selection app bar
              // carried as its title, in the same slot, still the
              // application's own translation.
              title: _selectionMode
                  ? l10n.selectedCount(_selectedTags.length)
                  : AppDestination.tags.label(context),
              toolbar: _selectionMode
                  ? _selectionToolbar(l10n, tagsAsync.value ?? const [])
                  : _browsingToolbar(l10n, tagsAsync.value ?? const []),
              body: ContentPort(
                ScreenBodyHost(
                  child: BaseInset(
                    all: Inset.roomy,
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
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stack) =>
                                _buildError(context, error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // What can be done to all of them at once. The screen states the
              // selection and the two operations; WHERE that lands - a bar
              // along the bottom here, a command bar plus a notice elsewhere -
              // is the skin's, which is why this is a slot and not a widget.
              selectionBar: _selectionMode && _selectedTags.isNotEmpty
                  ? SelectionBarSpec(
                      selectedCount: _selectedTags.length,
                      onClear: () {
                        setState(() {
                          _selectedTags.clear();
                        });
                      },
                      actions: <ToolbarGroup>[
                        ToolbarGroup(<ToolbarEntry>[
                          ToolbarActionEntry(
                            icon: IconRole.upload,
                            label: l10n.pushTagsCount(_selectedTags.length),
                            tooltip: l10n.pushTagsCount(_selectedTags.length),
                            // What the action MEANS, carried over:
                            // `TagsBatchOperationsBar` drew push with
                            // `ButtonVariant.secondary`, whose mapping is
                            // Tone.accent - the selection's affirmative
                            // action in the scheme's primary. An entry that
                            // stated nothing would default to neutral and
                            // come back onSurface, an appearance change
                            // nothing named.
                            tone: Tone.accent,
                            onPressed: () => _pushSelectedTags(context),
                          ),
                          ToolbarActionEntry(
                            icon: IconRole.trash,
                            label: l10n.deleteTagsCount(_selectedTags.length),
                            tooltip: l10n.deleteTagsCount(_selectedTags.length),
                            // What the action MEANS. `TagsBatchOperationsBar`
                            // said it with `ButtonVariant.danger`; the entry
                            // says it and the skin decides what destroying
                            // something looks like.
                            emphasis: Emphasis.primary,
                            tone: Tone.danger,
                            onPressed: () => _deleteSelectedTags(context),
                          ),
                        ]),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// The bar while the user is reading the tags: refresh, and everything else
  /// behind the overflow anchor.
  List<ToolbarGroup> _browsingToolbar(
    AppLocalizations l10n,
    List<GitTag> tags,
  ) {
    return <ToolbarGroup>[
      ToolbarGroup(<ToolbarEntry>[
        ToolbarActionEntry(
          icon: IconRole.arrowsClockwise,
          label: l10n.refresh,
          tooltip: l10n.refresh,
          onPressed: () => ref.read(gitActionsProvider).refreshTags(),
        ),
        ToolbarMenuEntry(
          icon: IconRole.dotsThreeVertical,
          tooltip: l10n.moreActions,
          entries: [
            // Select Tags action (only show if tags exist)
            if (tags.isNotEmpty)
              MenuAction(
                icon: IconRole.checkSquare,
                label: l10n.selectTags,
                onPressed: _enterSelectionMode,
              ),
            // Fetch Tags action
            if (tags.isNotEmpty) const MenuSeparator(),
            MenuAction(
              icon: IconRole.downloadSimple,
              label: l10n.fetchTags,
              onPressed: () => _fetchTags(context),
            ),
          ],
        ),
      ]),
    ];
  }

  /// The bar while tags are being picked.
  ///
  /// The way OUT of the mode and "check every one" are the two things this bar
  /// still offers; emptying the selection without leaving the mode is the
  /// selection bar's own `onClear`, which is where the contract puts it, so
  /// the app bar no longer carries a second control for it.
  List<ToolbarGroup> _selectionToolbar(
    AppLocalizations l10n,
    List<GitTag> tags,
  ) {
    return <ToolbarGroup>[
      ToolbarGroup(<ToolbarEntry>[
        ToolbarActionEntry(
          icon: IconRole.x,
          label: l10n.exitSelection,
          tooltip: l10n.exitSelection,
          onPressed: _exitSelectionMode,
        ),
        ToolbarActionEntry(
          icon: IconRole.checkSquareOffset,
          label: l10n.selectAll,
          tooltip: l10n.selectAll,
          onPressed: () => _selectAllTags(tags),
        ),
      ]),
    ];
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
        BaseInset(
          all: Inset.normal,
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
                  const BaseGap(Proximity.related),
                  BaseIconButton(
                    // One role, one mark; "the filter is engaged" travels
                    // as `isSelected` and the skin decides the weight.
                    icon: IconRole.funnel,
                    isSelected: _hasActiveFilters(),
                    tooltip: AppLocalizations.of(context)!.advancedFilters,
                    onPressed: () => _showAdvancedFiltersDialog(context, tags),
                    variant: ButtonVariant.secondary,
                  ),
                  const BaseGap(Proximity.related),
                  // The sort menu, through the contract's anchored form. Each
                  // row is a MenuChoice - "which one is in force" - so the
                  // selection signal (the checkCircle/circle pair this site
                  // used to draw by hand) is the SKIN's now, and the entry's
                  // own mark carries the one fact that is the application's:
                  // which way that entry orders the list.
                  Overlays.anchor(
                    spec: MenuAnchorSpec(
                      icon: IconRole.sortAscending,
                      tooltip: AppLocalizations.of(context)!.sortTags,
                    ),
                    entries: <MenuEntry>[
                      _sortChoice(
                        TagSortBy.nameAsc,
                        AppLocalizations.of(context)!.sortNameAZ,
                        IconRole.sortAscending,
                      ),
                      _sortChoice(
                        TagSortBy.nameDesc,
                        AppLocalizations.of(context)!.sortNameZA,
                        IconRole.sortDescending,
                      ),
                      const MenuSeparator(),
                      _sortChoice(
                        TagSortBy.dateNewest,
                        AppLocalizations.of(context)!.sortDateNewest,
                        IconRole.sortDescending,
                      ),
                      _sortChoice(
                        TagSortBy.dateOldest,
                        AppLocalizations.of(context)!.sortDateOldest,
                        IconRole.sortAscending,
                      ),
                      const MenuSeparator(),
                      _sortChoice(
                        TagSortBy.versionAsc,
                        AppLocalizations.of(context)!.sortVersionLowHigh,
                        IconRole.sortAscending,
                      ),
                      _sortChoice(
                        TagSortBy.versionDesc,
                        AppLocalizations.of(context)!.sortVersionHighLow,
                        IconRole.sortDescending,
                      ),
                    ],
                  ),
                  const BaseGap(Proximity.related),
                  // The group-by menu, anchored the same way. "A grouping is
                  // applied" used to be said by hand-picking the FILLED glyph
                  // and spelling out the accent colour at this call site -
                  // half a statement `IconRole` could not carry (conflict
                  // C3). It is `MenuAnchorSpec.selected` now, one fact from
                  // which the SKIN re-decides both the weight and the tint,
                  // which is exactly the resolution the old comment here said
                  // this site was waiting for.
                  Overlays.anchor(
                    spec: MenuAnchorSpec(
                      icon: IconRole.rows,
                      tooltip: AppLocalizations.of(context)!.groupTags,
                      selected: _groupBy != TagGroupBy.none,
                    ),
                    entries: <MenuEntry>[
                      _groupChoice(
                        TagGroupBy.none,
                        AppLocalizations.of(context)!.noGrouping,
                        null,
                      ),
                      const MenuSeparator(),
                      // Each entry's own mark names what it groups by; the
                      // selection signal is the skin's.
                      _groupChoice(
                        TagGroupBy.prefix,
                        AppLocalizations.of(context)!.byPrefix,
                        IconRole.textAa,
                      ),
                      _groupChoice(
                        TagGroupBy.version,
                        AppLocalizations.of(context)!.byVersion,
                        IconRole.gitBranch,
                      ),
                      _groupChoice(
                        TagGroupBy.author,
                        AppLocalizations.of(context)!.byAuthor,
                        IconRole.user,
                      ),
                      _groupChoice(
                        TagGroupBy.date,
                        AppLocalizations.of(context)!.byDate,
                        IconRole.calendar,
                      ),
                    ],
                  ),
                ],
              ),
              if (_hasActiveFilters()) ...[
                const BaseGap(Proximity.related),
                _buildActiveFiltersRow(),
              ],
              const BaseGap(Proximity.related),
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: BaseInset(
            x: Inset.normal,
            y: Inset.tight,
            child: Row(
              children: [
                // The count header's own mark, sitting inside a dense strip
                // whose height is the point: the row-level rung, not the
                // ordinary one a standalone glyph would take.
                const BaseIcon(IconRole.tag, scale: ControlScale.compact),
                const BaseGap(Proximity.related),
                BaseLabel(
                  '${filteredAndSortedTags.length} ${filteredAndSortedTags.length == 1 ? 'Tag' : 'Tags'}',
                  role: TextRole.sectionTitle,
                ),
                if (_searchQuery.isNotEmpty ||
                    _filterType != TagFilterType.all) ...[
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(context)!.ofTotal(tags.length),
                    role: TextRole.detail,
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
    return Center(
      child: BaseLabel('No tags match your search', role: TextRole.body),
    );
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
          // The group header's mark is drawn BOLD on purpose - the weight
          // census records this file as one of the surfaces still waiting for
          // `MaterialGlyphs.boldOf` - and a weight is the one thing `IconRole`
          // deliberately cannot carry, so the mark stays a raw `Icon` naming
          // Phosphor's bold constant. Its colour is stranded with it: a `Tone`
          // reaches a mark only through `BaseIcon`, which cannot say the
          // weight, so naming `Tone.accent` here would cost the bold stroke.
          leading: Icon(
            PhosphorIconsBold.folder,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: BaseLabel(groupName, role: TextRole.sectionTitle),
          subtitle: BaseLabel(
            '${groupTags.length} ${groupTags.length == 1 ? 'tag' : 'tags'}',
            role: TextRole.detail,
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

  /// One sort-menu entry: "which one is in force" as a [MenuChoice], with
  /// [direction] - the way this entry orders the list - as the entry's own
  /// mark. Where that mark sits relative to the skin's selection signal is
  /// the skin's answer.
  MenuChoice _sortChoice(TagSortBy sortBy, String label, IconRole direction) =>
      MenuChoice(
        label: label,
        selected: _sortBy == sortBy,
        icon: direction,
        onSelect: () => setState(() => _sortBy = sortBy),
      );

  /// One group-menu entry: the same shape, with [kind] naming what the entry
  /// groups by - and null for "no grouping", which has no key to name.
  MenuChoice _groupChoice(TagGroupBy groupBy, String label, IconRole? kind) =>
      MenuChoice(
        label: label,
        selected: _groupBy == groupBy,
        icon: kind,
        onSelect: () => setState(() => _groupBy = groupBy),
      );

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
          : await Overlays.dialogFrom<String>(
              context,
              route: DialogRouteSpec(
                title: AppLocalizations.of(context)!.selectRemoteDialog,
              ),
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
          : await Overlays.dialogFrom<String>(
              context,
              route: DialogRouteSpec(
                title: AppLocalizations.of(context)!.selectRemoteDialog,
              ),
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
            : await Overlays.dialogFrom<String>(
                context,
                route: DialogRouteSpec(
                  title: AppLocalizations.of(context)!.selectRemoteDialog,
                ),
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
