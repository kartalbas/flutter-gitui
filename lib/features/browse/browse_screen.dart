import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/components/base_animated_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_diff_viewer.dart';
import '../../shared/components/base_label.dart';
import '../../shared/utils/search_parser.dart';
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

      // Check if file belongs to current repository
      if (!normalizedFilePath.startsWith(normalizedRepoPath)) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppDestination.browse.label(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            _buildToolbar(context),
            const SizedBox(height: AppTheme.paddingM),
            // Main content
            Expanded(
              child: NotificationListener<ScrollNotification>(
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
                      Row(
                        children: [
                          // Left: File tree view (resizable)
                          SizedBox(
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

                          // Resizable divider
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                final newWidth = (treeViewWidth + details.delta.dx)
                                    .clamp(_minTreeViewWidth, _maxTreeViewWidth);
                                ref.read(_browseTreeWidthProvider.notifier).state = newWidth;
                              },
                              child: Container(
                                width: 8,
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
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
                            child: shouldClearSelection || selectedFile == null
                                ? const BrowseNoFileSelectedState()
                                : viewMode == BrowseViewMode.history
                                    ? FileHistoryPanel(filePath: selectedFile)
                                    : viewMode == BrowseViewMode.blame
                                        ? FileBlamePanel(filePath: selectedFile)
                                        : FilePreviewPanel(filePath: selectedFile),
                          ),
                        ],
                      ),
                      // Draggable Speed Dial FAB for file operations
                      _DraggableSpeedDial(
                        actions: (_treeViewKey.currentState as FileTreeViewState?)?.fabActions ?? [],
                        isExpanded: _fabIsExpanded,
                        onToggle: _toggleFAB,
                        onCollapse: _collapseFAB,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final viewMode = ref.watch(browseViewModeProvider);
    final showHidden = ref.watch(showHiddenFilesProvider);
    final showIgnored = ref.watch(showIgnoredFilesProvider);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: BaseTextField(
              controller: _searchController,
              hintText: SearchParser.getHelpText(_searchMode),
              prefixIcon: PhosphorIconsRegular.magnifyingGlass,
              showClearButton: _searchController.text.isNotEmpty,
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: AppTheme.paddingS),

          // Search mode toggle
          SegmentedButton<SearchMode>(
            segments: [
              ButtonSegment(
                value: SearchMode.simple,
                label: LabelSmallLabel('Aa'),
                tooltip: 'Simple search (case-insensitive)',
              ),
              ButtonSegment(
                value: SearchMode.glob,
                label: LabelSmallLabel('*'),
                tooltip: 'Glob pattern (*.json, *ABN*/file)',
              ),
              ButtonSegment(
                value: SearchMode.regex,
                label: LabelSmallLabel('.*'),
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

          const SizedBox(width: AppTheme.paddingS),

          // View mode toggle
          SegmentedButton<BrowseViewMode>(
            segments: [
              ButtonSegment(
                value: BrowseViewMode.history,
                icon: Icon(PhosphorIconsRegular.clockCounterClockwise, size: 18),
                label: MenuItemLabel(AppLocalizations.of(context)!.history),
              ),
              ButtonSegment(
                value: BrowseViewMode.blame,
                icon: Icon(PhosphorIconsRegular.users, size: 18),
                label: MenuItemLabel(AppLocalizations.of(context)!.blame),
              ),
              ButtonSegment(
                value: BrowseViewMode.preview,
                icon: Icon(PhosphorIconsRegular.eye, size: 18),
                label: MenuItemLabel(AppLocalizations.of(context)!.preview),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (Set<BrowseViewMode> selection) {
              ref.read(configProvider.notifier).setBrowseViewMode(selection.first);
            },
          ),

          const SizedBox(width: AppTheme.paddingS),

          // Options menu
          BasePopupMenuButton<void>(
            icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
            tooltip: AppLocalizations.of(context)!.viewOptions,
            itemBuilder: (context) {
              return <PopupMenuEntry<void>>[
                CheckedPopupMenuItem<void>(
                  checked: showHidden,
                  onTap: () {
                    ref.read(configProvider.notifier).setShowHiddenFiles(!showHidden);
                  },
                  child: MenuItemLabel(
                    AppLocalizations.of(context)!.showHiddenFiles,
                  ),
                ),
                CheckedPopupMenuItem<void>(
                  checked: showIgnored,
                  onTap: () {
                    ref.read(configProvider.notifier).setShowIgnoredFiles(!showIgnored);
                  },
                  child: MenuItemLabel(
                    AppLocalizations.of(context)!.showIgnoredFiles,
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
                  child: MenuItemLabel(
                    AppLocalizations.of(context)!.expandAll,
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
                  child: MenuItemLabel(
                    AppLocalizations.of(context)!.collapseAll,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

/// Draggable Speed Dial FAB for file operations
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
