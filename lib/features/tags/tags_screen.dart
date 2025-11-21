import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../shared/components/base_animated_widgets.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_menu_item.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/tag.dart';
import '../../core/navigation/navigation_item.dart';
import 'dialogs/advanced_filters_dialog.dart' show AdvancedFiltersDialog, DateRangeFilter;
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

  String _searchQuery = '';
  TagFilterType _filterType = TagFilterType.all;
  bool _selectionMode = false;
  final Set<String> _selectedTags = {};

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: _selectionMode
              ? AppBar(
                  title: Text(AppLocalizations.of(context)!.selectedCount(_selectedTags.length)),
                  leading: BaseIconButton(
                    icon: PhosphorIconsRegular.x,
                    tooltip: AppLocalizations.of(context)!.exitSelection,
                    onPressed: () {
                      setState(() {
                        _selectionMode = false;
                        _selectedTags.clear();
                      });
                    },
                  ),
                  actions: [
                    BaseIconButton(
                      icon: PhosphorIconsRegular.checkSquareOffset,
                      tooltip: AppLocalizations.of(context)!.selectAll,
                      onPressed: () => _selectAllTags(tagsAsync.value ?? []),
                    ),
                    BaseIconButton(
                      icon: PhosphorIconsRegular.square,
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
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.checkSquare,
                          label: AppLocalizations.of(context)!.selectTags,
                        ),
                        onTap: () {
                          setState(() {
                            _selectionMode = true;
                          });
                        },
                      ),
                    // Fetch Tags action
                    if (tagsAsync.value?.isNotEmpty == true)
                      const PopupMenuDivider(),
                    PopupMenuItem(
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.downloadSimple,
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
                    data: (tags) => _buildTagList(context, tags, localOnlyTags, remoteOnlyTags, remotes),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => _buildError(context, error),
                  ),
                ),
              ],
            ),
          ),
      bottomNavigationBar: _selectionMode && _selectedTags.isNotEmpty
          ? _buildBatchOperationsBar(context)
          : null,
    );
  }

  Widget _buildNoRepository(BuildContext context) {
    return const TagsNoRepositoryState();
  }

  Widget _buildError(BuildContext context, Object error) {
    return TagsErrorState(error: error);
  }

  Widget _buildTagList(BuildContext context, List<GitTag> tags, Set<String> localOnlyTags, Set<String> remoteOnlyTags, List<String> remotes) {
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
                      hintText: _useRegex ? 'Regex search...' : 'Search tags...',
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
                    icon: _hasActiveFilters()
                        ? PhosphorIconsBold.funnel
                        : PhosphorIconsRegular.funnel,
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortNameAZ)),
                            const Icon(PhosphorIconsRegular.sortAscending, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortNameZA)),
                            const Icon(PhosphorIconsRegular.sortDescending, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortDateNewest)),
                            const Icon(PhosphorIconsRegular.sortDescending, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortDateOldest)),
                            const Icon(PhosphorIconsRegular.sortAscending, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortVersionLowHigh)),
                            const Icon(PhosphorIconsRegular.sortAscending, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.sortVersionHighLow)),
                            const Icon(PhosphorIconsRegular.sortDescending, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BasePopupMenuButton<TagGroupBy>(
                    icon: Icon(
                      _groupBy != TagGroupBy.none
                          ? PhosphorIconsBold.rows
                          : PhosphorIconsRegular.rows,
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.noGrouping)),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.byPrefix)),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.byVersion)),
                            const Icon(PhosphorIconsRegular.gitBranch, size: 16),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.byAuthor)),
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
                            Expanded(child: BodyMediumLabel(AppLocalizations.of(context)!.byDate)),
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
                allTags: filteredAndSortedTags,
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
              if (_searchQuery.isNotEmpty || _filterType != TagFilterType.all) ...[
                const SizedBox(width: AppTheme.paddingS),
                BodySmallLabel(
                  'of ${tags.length}',
                ),
              ],
              const Spacer(),
              if (localOnlyTags.isNotEmpty)
                BaseButton(
                  label: 'Push ${localOnlyTags.length}',
                  variant: ButtonVariant.secondary,
                  leadingIcon: PhosphorIconsRegular.upload,
                  onPressed: () => _pushAllTags(context),
                ),
            ],
          ),
        ),

        // Tag list
        Expanded(
          child: filteredAndSortedTags.isEmpty
              ? Center(
                  child: BodyLargeLabel(
                    'No tags match your search',
                  ),
                )
              : _buildGroupedTagList(filteredAndSortedTags, localOnlyTags, remotes),
        ),
      ],
    );
  }

  /// Build grouped tag list with collapsible group headers
  Widget _buildGroupedTagList(List<GitTag> tags, Set<String> localOnlyTags, List<String> remotes) {
    final groupedTags = _tagsService.groupTags(tags: tags, groupBy: _groupBy);

    if (_groupBy == TagGroupBy.none) {
      // No grouping - show simple list
      return ListView.builder(
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
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
        },
      );
    }

    // Grouped view with collapsible sections
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
          title: TitleMediumLabel(
            groupName,
          ),
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
    return const TagsEmptyState();
  }

  void _selectAllTags(List<GitTag> tags) {
    setState(() {
      // Apply same filters as the list view
      final filteredAndSortedTags = tags.where((tag) {
        // Apply type filter
        if (_filterType == TagFilterType.annotated && !tag.isAnnotated) {
          return false;
        }
        if (_filterType == TagFilterType.lightweight && !tag.isLightweight) {
          return false;
        }

        // Apply search filter
        if (_searchQuery.isEmpty) return true;

        final query = _searchQuery.toLowerCase();
        return tag.name.toLowerCase().contains(query) ||
               tag.displayMessage.toLowerCase().contains(query) ||
               tag.commitHash.toLowerCase().contains(query);
      });

      _selectedTags.addAll(filteredAndSortedTags.map((tag) => tag.name));
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

  Future<void> _showAdvancedFiltersDialog(BuildContext context, List<GitTag> allTags) async {
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
    try {
      await ref.read(gitActionsProvider).fetchTags();
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackbarTagsFetched)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToFetchTags(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pushAllTags(BuildContext context) async {
    final remotes = await ref.read(remoteNamesProvider.future);

    if (remotes.isEmpty) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackbarNoRemotesConfigured)),
        );
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
        try {
          await ref.read(gitActionsProvider).pushAllTags(remoteName);
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.snackbarAllTagsPushed(remoteName))),
            );
          }
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.snackbarFailedToPushTags(e.toString())),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackbarNoRemotesConfigured)),
        );
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
        try {
          // Use batch operation to push all selected tags at once
          await ref.read(gitActionsProvider).pushTags(
            remoteName,
            _selectedTags.toList(),
          );

          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.snackbarTagsPushed(_selectedTags.length, remoteName)),
              ),
            );
            setState(() {
              _selectionMode = false;
              _selectedTags.clear();
            });
          }
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.snackbarFailedToPushTags(e.toString())),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
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
      builder: (context) => DeleteTagsDialog(
        tagNames: _selectedTags,
        hasRemotes: hasRemotes,
      ),
    );

    if (result != null && result['confirmed'] == true && context.mounted) {
      final deleteFromRemote = result['deleteFromRemote'] == true;

      try {
        // Get remote name if deleting from remote
        String? remoteName;
        if (deleteFromRemote && hasRemotes) {
          remoteName = remotes.contains('origin') ? 'origin' : remotes.first;
        }

        // Use batch operation to delete all selected tags at once
        await ref.read(gitActionsProvider).deleteTags(
          _selectedTags.toList(),
          deleteFromRemote: deleteFromRemote,
          remoteName: remoteName,
        );

        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarTagsDeleted(_selectedTags.length)),
            ),
          );
          setState(() {
            _selectionMode = false;
            _selectedTags.clear();
          });
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToDeleteTags(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

}

/// Tag filter type
enum TagFilterType {
  all,
  annotated,
  lightweight,
}

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
enum TagGroupBy {
  none,
  prefix,
  version,
  author,
  date,
}

