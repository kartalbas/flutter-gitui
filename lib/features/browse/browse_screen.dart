import 'dart:io';
import 'package:flutter/material.dart';
import '../../shared/components/base_animated_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole;
import 'package:path/path.dart' as path;

import '../../generated/app_localizations.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_layout.dart';
import '../../shared/components/base_speed_dial.dart';
import '../../shared/utils/search_parser.dart';
import '../../shared/widgets/base_dismiss_scope.dart';
import '../../shared/widgets/base_focus_region.dart';
import '../../shared/widgets/search_field_handoff.dart';
import '../../core/config/config_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/navigation_item.dart';
import 'widgets/file_tree_view.dart';
import 'widgets/file_history_panel.dart';
import 'widgets/file_preview_panel.dart';
import 'widgets/file_blame_panel.dart';
import 'widgets/browse_no_repository_state.dart';
import 'widgets/browse_no_file_selected_state.dart';

/// Selected file provider (for tree view selection) - Not persisted
final selectedFileProvider = StateProvider<String?>((ref) => null);

/// Tree view width provider - persists width when navigating away
final _browseTreeWidthProvider = StateProvider<double>((ref) => 300.0);

/// Browse screen - Repository file browser with tree view
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ConsumerState<FileTreeView>> _treeViewKey = GlobalKey();
  bool _fabIsExpanded = false;
  SearchMode _searchMode = SearchMode.simple;
  static const double _minTreeViewWidth = 200.0;
  static const double _maxTreeViewWidth = 600.0;

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

  /// The "clear the search" rung of the Escape ladder, also what the field's
  /// clear button does: empty the text and show the unfiltered tree again.
  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // The tree mounts after the toolbar's first build, so the search field's
    // handoff to the tree's controller can only attach on the next frame;
    // rebuild once so it does not wait for the first keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final viewMode = ref.watch(browseViewModeProvider);
    final showHidden = ref.watch(showHiddenFilesProvider);
    final showIgnored = ref.watch(showIgnoredFilesProvider);
    final treeViewWidth = ref.watch(_browseTreeWidthProvider);

    // No repository open
    if (repositoryPath == null) {
      return const BrowseNoRepositoryState();
    }

    // Check if selected file belongs to current repository or exists
    bool shouldClearSelection = false;
    if (selectedFile != null) {
      // Normalize paths for comparison
      final normalizedRepoPath = path.normalize(repositoryPath);
      final normalizedFilePath = path.normalize(selectedFile);

      // A prefix test would accept a sibling repository whose path starts with the
      // same characters (D:\repos\app-v2 under D:\repos\app); isWithin compares whole
      // path segments and is case-insensitive on Windows.
      if (!path.isWithin(normalizedRepoPath, normalizedFilePath)) {
        shouldClearSelection = true;
      }
      // Check if file exists
      else if (!File(selectedFile).existsSync()) {
        shouldClearSelection = true;
      }
    }

    if (shouldClearSelection) {
      // Clear selection on next frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedFileProvider.notifier).state = null;
      });
    }

    // The Escape ladder, innermost rung first: collapse the expanded speed
    // dial, then clear the search text, then nothing — browse has no mode
    // beyond its filter. When the field itself holds focus its own watcher
    // clears the text before either rung.
    return BaseDismissScope(
      enabled: _searchController.text.isNotEmpty,
      onDismiss: _clearSearch,
      child: BaseDismissScope(
        enabled: _fabIsExpanded,
        onDismiss: _collapseFAB,
        child: Scaffold(
          appBar: AppBar(title: Text(AppDestination.browse.label(context))),
          // The screen's ordered focus regions: toolbar with the search
          // field (1), tree (2), viewer pane (3), action dial (4). Nested
          // inside the shell's content region, so F6 and the focus of last
          // resort stay with the shell.
          body: BaseFocusRegionHost(
            debugLabel: 'BrowseScreen.regions',
            // The screen holds its panes off the window's edge at the
            // generous distance every screen of the application uses:
            // `Inset.roomy`, which Material answers with the 24 this line
            // used to name.
            child: BaseInset(
              all: Inset.roomy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toolbar
                  BaseFocusRegion(
                    order: 1,
                    debugLabel: 'BrowseScreen.toolbarRegion',
                    child: _buildToolbar(context),
                  ),
                  // The toolbar and the panes under it are members of one
                  // group: `grouped`.
                  const BaseGap(Proximity.grouped),
                  // Main content
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Collapse FAB when scrolling starts
                        if (notification is ScrollStartNotification &&
                            _fabIsExpanded) {
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
                            Row(
                              children: [
                                // Left: File tree view (resizable)
                                BaseFocusRegion(
                                  order: 2,
                                  debugLabel: 'BrowseScreen.treeRegion',
                                  child: SizedBox(
                                    width: treeViewWidth,
                                    child: FileTreeView(
                                      key: _treeViewKey,
                                      repositoryPath: repositoryPath,
                                      searchQuery: _searchController.text,
                                      searchMode: _searchMode,
                                      showHidden: showHidden,
                                      showIgnored: showIgnored,
                                    ),
                                  ),
                                ),

                                // Resizable divider
                                MouseRegion(
                                  cursor: SystemMouseCursors.resizeColumn,
                                  child: GestureDetector(
                                    onHorizontalDragUpdate: (details) {
                                      final newWidth =
                                          (treeViewWidth + details.delta.dx)
                                              .clamp(
                                                _minTreeViewWidth,
                                                _maxTreeViewWidth,
                                              );
                                      ref
                                              .read(
                                                _browseTreeWidthProvider
                                                    .notifier,
                                              )
                                              .state =
                                          newWidth;
                                    },
                                    child: Container(
                                      width: 8,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withValues(alpha: 0),
                                      child: Center(
                                        child: Container(
                                          width: 1,
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Right: File history, preview, or blame
                                Expanded(
                                  child: BaseFocusRegion(
                                    order: 3,
                                    debugLabel: 'BrowseScreen.viewerRegion',
                                    child:
                                        shouldClearSelection ||
                                            selectedFile == null
                                        ? const BrowseNoFileSelectedState()
                                        : viewMode == BrowseViewMode.history
                                        ? FileHistoryPanel(
                                            filePath: selectedFile,
                                          )
                                        : viewMode == BrowseViewMode.blame
                                        ? FileBlamePanel(filePath: selectedFile)
                                        : FilePreviewPanel(
                                            filePath: selectedFile,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            // Draggable Speed Dial FAB for file operations —
                            // the screen's action bar, last on the Tab walk.
                            BaseFocusRegion(
                              order: 4,
                              debugLabel: 'BrowseScreen.actionsRegion',
                              child: BaseSpeedDial(
                                actions:
                                    (_treeViewKey.currentState
                                            as FileTreeViewState?)
                                        ?.fabActions ??
                                    [],
                                isExpanded: _fabIsExpanded,
                                onToggle: _toggleFAB,
                                onCollapse: _collapseFAB,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final viewMode = ref.watch(browseViewModeProvider);
    final showHidden = ref.watch(showHiddenFilesProvider);
    final showIgnored = ref.watch(showIgnoredFilesProvider);

    // The tree's controller, once the tree has mounted (initState schedules
    // the one rebuild that picks it up). With it in hand, arrows typed in
    // the search field move the tree's highlight while the caret stays put.
    final treeController =
        (_treeViewKey.currentState as FileTreeViewState?)?.treeController;

    Widget searchField = BaseTextField(
      controller: _searchController,
      hintText: SearchParser.getHelpText(_searchMode),
      prefixIcon: IconRole.magnifyingGlass,
      showClearButton: _searchController.text.isNotEmpty,
      onChanged: (_) => setState(() {}),
    );
    if (treeController != null) {
      searchField = SearchFieldHandoff(
        controller: treeController,
        child: searchField,
      );
    }

    return Container(
      // The toolbar's fill stays: it is the surface. How tightly the strip
      // holds its controls is the language's question - `tight`, the 8 this
      // container named.
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: BaseInset(
        all: Inset.tight,
        child: Row(
          children: [
            // Search field
            Expanded(child: searchField),

            const BaseGap(Proximity.related),

            // Search mode toggle
            SegmentedButton<SearchMode>(
              segments: [
                ButtonSegment(
                  value: SearchMode.simple,
                  label: const BaseLabel('Aa', role: TextRole.micro),
                  tooltip: 'Simple search (case-insensitive)',
                ),
                ButtonSegment(
                  value: SearchMode.glob,
                  label: const BaseLabel('*', role: TextRole.micro),
                  tooltip: 'Glob pattern (*.json, *ABN*/file)',
                ),
                ButtonSegment(
                  value: SearchMode.regex,
                  label: const BaseLabel('.*', role: TextRole.micro),
                  tooltip: 'Regular expression',
                ),
              ],
              selected: {_searchMode},
              onSelectionChanged: (Set<SearchMode> selection) {
                setState(() {
                  _searchMode = selection.first;
                });
              },
            ),

            const BaseGap(Proximity.related),

            // View mode toggle
            SegmentedButton<BrowseViewMode>(
              segments: [
                ButtonSegment(
                  value: BrowseViewMode.history,
                  icon: Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    size: 18,
                  ),
                  label: BaseLabel(
                    AppLocalizations.of(context)!.history,
                    role: TextRole.control,
                  ),
                ),
                ButtonSegment(
                  value: BrowseViewMode.blame,
                  icon: Icon(PhosphorIconsRegular.users, size: 18),
                  label: BaseLabel(
                    AppLocalizations.of(context)!.blame,
                    role: TextRole.control,
                  ),
                ),
                ButtonSegment(
                  value: BrowseViewMode.preview,
                  icon: Icon(PhosphorIconsRegular.eye, size: 18),
                  label: BaseLabel(
                    AppLocalizations.of(context)!.preview,
                    role: TextRole.control,
                  ),
                ),
              ],
              selected: {viewMode},
              onSelectionChanged: (Set<BrowseViewMode> selection) {
                ref
                    .read(configProvider.notifier)
                    .setBrowseViewMode(selection.first);
              },
            ),

            const BaseGap(Proximity.related),

            // Options menu
            BasePopupMenuButton<void>(
              icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
              tooltip: AppLocalizations.of(context)!.viewOptions,
              itemBuilder: (context) {
                return <PopupMenuEntry<void>>[
                  CheckedPopupMenuItem<void>(
                    checked: showHidden,
                    onTap: () {
                      ref
                          .read(configProvider.notifier)
                          .setShowHiddenFiles(!showHidden);
                    },
                    child: BaseLabel(
                      AppLocalizations.of(context)!.showHiddenFiles,
                      role: TextRole.control,
                    ),
                  ),
                  CheckedPopupMenuItem<void>(
                    checked: showIgnored,
                    onTap: () {
                      ref
                          .read(configProvider.notifier)
                          .setShowIgnoredFiles(!showIgnored);
                    },
                    child: BaseLabel(
                      AppLocalizations.of(context)!.showIgnoredFiles,
                      role: TextRole.control,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<void>(
                    onTap: () {
                      // Access the tree view state and expand all
                      final treeState = _treeViewKey.currentState as dynamic;
                      if (treeState != null) {
                        treeState.expandAll();
                      }
                    },
                    child: BaseLabel(
                      AppLocalizations.of(context)!.expandAll,
                      role: TextRole.control,
                    ),
                  ),
                  PopupMenuItem<void>(
                    onTap: () {
                      // Access the tree view state and collapse all
                      final treeState = _treeViewKey.currentState as dynamic;
                      if (treeState != null) {
                        treeState.collapseAll();
                      }
                    },
                    child: BaseLabel(
                      AppLocalizations.of(context)!.collapseAll,
                      role: TextRole.control,
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
