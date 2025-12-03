import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as p;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_diff_viewer.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/controllers/tree_view_controller.dart';
import '../../../shared/utils/search_parser.dart';
import '../../../shared/utils/file_icon_utils.dart';
import '../../../shared/widgets/base_tree_item.dart';
import '../../../shared/widgets/file_status_badge.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/file_status.dart';
import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_dialog.dart';
import '../browse_screen.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/editor_launcher_service.dart';
import '../../../core/services/notification_service.dart';

/// File tree node with TreeNodeMixin for keyboard navigation support
class FileTreeNode with TreeNodeMixin {
  @override
  final String name;
  @override
  final String fullPath;
  @override
  final bool isDirectory;
  @override
  final List<FileTreeNode> children;
  @override
  bool isExpanded;
  FileStatusType? status;

  FileTreeNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    List<FileTreeNode>? children,
    this.isExpanded = false,
    this.status,
  }) : children = children ?? [];
}

/// Provider to persist scroll offset across navigation
final _browseScrollOffsetProvider = StateProvider<double>((ref) => 0.0);

/// Provider to persist the tree nodes across navigation
final _browseTreeNodesProvider = StateProvider<List<FileTreeNode>>((ref) => []);

/// Provider to track if tree was previously loaded for this repository
final _browseTreeLoadedForProvider = StateProvider<String?>((ref) => null);

/// File tree view widget
class FileTreeView extends ConsumerStatefulWidget {
  final String repositoryPath;
  final String searchQuery;
  final SearchMode searchMode;
  final bool showHidden;
  final bool showIgnored;

  const FileTreeView({
    super.key,
    required this.repositoryPath,
    required this.searchQuery,
    this.searchMode = SearchMode.simple,
    required this.showHidden,
    required this.showIgnored,
  });

  @override
  ConsumerState<FileTreeView> createState() => FileTreeViewState();
}

class FileTreeViewState extends ConsumerState<FileTreeView> {
  List<FileTreeNode> _rootNodes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _copiedFilePath; // Clipboard for copy/paste
  late final TreeViewController<FileTreeNode> _treeController;
  String? _previousBranch; // Track branch changes
  String _lastSearchQuery = ''; // Track search query changes
  SearchMode _lastSearchMode = SearchMode.simple; // Track search mode changes
  Timer? _searchDebounce; // Debounce timer for search

  // Provider notifiers saved for safe dispose
  late final StateController<List<FileTreeNode>> _treeNodesNotifier;
  late final StateController<String?> _loadedForNotifier;
  late final StateController<double> _scrollOffsetNotifier;

  @override
  void initState() {
    super.initState();

    // Save provider notifiers for safe dispose
    _treeNodesNotifier = ref.read(_browseTreeNodesProvider.notifier);
    _loadedForNotifier = ref.read(_browseTreeLoadedForProvider.notifier);
    _scrollOffsetNotifier = ref.read(_browseScrollOffsetProvider.notifier);

    _treeController = TreeViewController<FileTreeNode>(
      itemHeight: 32.0,
      skipDirectories: false,
      onSelectionChanged: (node) {
        if (node != null && !node.isDirectory) {
          ref.read(selectedFileProvider.notifier).state = node.fullPath;
        }
      },
      onLoadChildren: _loadNodeChildren,
    );

    // Listen for git status changes to update file statuses
    // This handles external changes like git restore, checkout, etc.
    ref.listenManual(repositoryStatusProvider, (previous, next) {
      final statuses = next.value;
      if (statuses != null && _rootNodes.isNotEmpty) {
        _applyStatuses(_rootNodes, statuses);
        // Notify tree controller to rebuild with updated statuses
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        _treeController.notifyListeners();
      }
    });

    // Check if we have cached state for this repository
    final loadedFor = ref.read(_browseTreeLoadedForProvider);
    if (loadedFor == widget.repositoryPath) {
      // Restore cached state
      final cachedNodes = ref.read(_browseTreeNodesProvider);
      if (cachedNodes.isNotEmpty) {
        _rootNodes = cachedNodes;

        // Apply latest statuses to cached nodes (status may have changed while in other view)
        final statusAsync = ref.read(repositoryStatusProvider);
        final statuses = statusAsync.value ?? [];
        _applyStatuses(_rootNodes, statuses);

        _treeController.updateNodes(_rootNodes);
        _isLoading = false;

        // Restore scroll position and selection after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Restore scroll position
            if (_treeController.scrollController.hasClients) {
              final savedOffset = ref.read(_browseScrollOffsetProvider);
              _treeController.scrollController.jumpTo(savedOffset);
            }
            // Restore selection
            final selectedFile = ref.read(selectedFileProvider);
            if (selectedFile != null) {
              _treeController.selectByPath(selectedFile);
            }
          }
        });
        return;
      }
    }

    _loadFileTree();
  }

  /// Load children for a directory node (lazy loading)
  Future<bool> _loadNodeChildren(FileTreeNode node) async {
    if (!node.isDirectory) return false;

    try {
      final children = await _buildTreeNodes(node.fullPath);

      // Apply file statuses to the new children
      final statusAsync = ref.read(repositoryStatusProvider);
      final statuses = statusAsync.value ?? [];
      _applyStatuses(children, statuses);

      node.children.addAll(children);
      return true;
    } catch (e) {
      Logger.error('Error loading children for ${node.fullPath}', e);
      return false;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    // Save state to providers after frame completes to avoid modifying during build
    if (_rootNodes.isNotEmpty) {
      final nodes = _rootNodes;
      final repoPath = widget.repositoryPath;
      final scrollOffset = _treeController.scrollController.hasClients
          ? _treeController.scrollController.offset
          : 0.0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _treeNodesNotifier.state = nodes;
        _loadedForNotifier.state = repoPath;
        _scrollOffsetNotifier.state = scrollOffset;
      });
    }

    _treeController.dispose();
    super.dispose();
  }

  /// Get the currently selected node for keyboard shortcuts
  FileTreeNode? get _selectedNode => _treeController.selectedNode;

  @override
  void didUpdateWidget(FileTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if branch has changed
    final currentBranch = ref.read(currentBranchProvider).value;
    final branchChanged = _previousBranch != null && _previousBranch != currentBranch;

    // Clear cache if repository changed
    if (oldWidget.repositoryPath != widget.repositoryPath) {
      ref.read(_browseTreeNodesProvider.notifier).state = [];
      ref.read(_browseTreeLoadedForProvider.notifier).state = null;
      ref.read(_browseScrollOffsetProvider.notifier).state = 0.0;
    }

    if (oldWidget.repositoryPath != widget.repositoryPath ||
        oldWidget.showHidden != widget.showHidden ||
        oldWidget.showIgnored != widget.showIgnored ||
        branchChanged) {
      _loadFileTree();
    }

    _previousBranch = currentBranch;

    // Trigger search when query or mode changes (with debouncing)
    final queryChanged = widget.searchQuery != _lastSearchQuery;
    final modeChanged = widget.searchMode != _lastSearchMode;

    if (queryChanged || modeChanged) {
      _lastSearchQuery = widget.searchQuery;
      _lastSearchMode = widget.searchMode;

      // Cancel any pending search
      _searchDebounce?.cancel();

      if (widget.searchQuery.isEmpty) {
        // Reset to normal view immediately
        _treeController.updateNodes(_rootNodes);
      } else {
        // Debounce search to wait for user to stop typing (300ms)
        // If only mode changed, search immediately
        final debounceTime = queryChanged ? 300 : 0;
        _searchDebounce = Timer(Duration(milliseconds: debounceTime), () {
          if (mounted && widget.searchQuery.isNotEmpty) {
            _performSearch(widget.searchQuery);
          }
        });
      }
    }
  }

  /// Perform async search through all files and folders
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    // Skip if already searching (prevent concurrent modification)
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      // Load and expand all folders that contain matches
      await _searchAndExpandNodes(_rootNodes, query);

      // Check if query is still valid (user may have typed more)
      if (!mounted || widget.searchQuery != query) return;

      // Filter to show only matching items
      final filteredNodes = _filterNodes(_rootNodes, query);
      _treeController.updateNodes(filteredNodes);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// Expand all directories in the tree
  Future<void> expandAll() async {
    await _expandAllNodes(_rootNodes);
    setState(() {});
  }

  /// Collapse all directories in the tree
  void collapseAll() {
    _collapseAllNodes(_rootNodes);
    setState(() {});
  }

  Future<void> _expandAllNodes(List<FileTreeNode> nodes) async {
    for (final node in nodes) {
      if (node.isDirectory) {
        if (node.children.isEmpty) {
          // Load children
          final children = await _buildTreeNodes(node.fullPath);
          node.children.addAll(children);
        }
        node.isExpanded = true;
        await _expandAllNodes(node.children);
      }
    }
  }

  void _collapseAllNodes(List<FileTreeNode> nodes) {
    for (final node in nodes) {
      if (node.isDirectory) {
        node.isExpanded = false;
        _collapseAllNodes(node.children);
      }
    }
  }

  Future<void> _loadFileTree() async {
    setState(() => _isLoading = true);

    try {
      final dir = Directory(widget.repositoryPath);
      final nodes = await _buildTreeNodes(dir.path, isRoot: true);

      // Get file statuses
      final statusAsync = ref.read(repositoryStatusProvider);
      final statuses = statusAsync.value ?? [];

      // Apply statuses to nodes
      _applyStatuses(nodes, statuses);

      setState(() {
        _rootNodes = nodes;
        _isLoading = false;
      });

      // Update tree controller with new nodes
      _treeController.updateNodes(_rootNodes);
    } catch (e) {
      Logger.error('Error loading file tree', e);
      setState(() => _isLoading = false);
    }
  }

  Future<List<FileTreeNode>> _buildTreeNodes(String dirPath, {bool isRoot = false}) async {
    final dir = Directory(dirPath);
    final nodes = <FileTreeNode>[];

    try {
      final entities = await dir.list().toList();

      // Sort: directories first, then files
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(
          p.basename(b.path).toLowerCase(),
        );
      });

      for (final entity in entities) {
        final name = p.basename(entity.path);

        // Skip .git directory
        if (name == '.git') continue;

        // Skip hidden files if not shown
        if (!widget.showHidden && name.startsWith('.')) continue;

        final isDirectory = entity is Directory;

        nodes.add(FileTreeNode(
          name: name,
          fullPath: entity.path,
          isDirectory: isDirectory,
          children: [], // Load children on expand
        ));
      }
    } catch (e) {
      Logger.error('Error reading directory $dirPath', e);
    }

    return nodes;
  }

  void _applyStatuses(List<FileTreeNode> nodes, List<FileStatus> statuses) {
    for (final node in nodes) {
      // Find matching status
      // Normalize path separators: git uses forward slashes, Windows uses backslashes
      final relativePath = p.relative(node.fullPath, from: widget.repositoryPath).replaceAll('\\', '/');
      final status = statuses.firstWhere(
        (s) => s.path == relativePath,
        orElse: () => const FileStatus(
          path: '',
          indexStatus: FileStatusType.unchanged,
          workTreeStatus: FileStatusType.unchanged,
        ),
      );

      // Set status if changed, or clear it if unchanged
      if (status.primaryStatus != FileStatusType.unchanged) {
        node.status = status.primaryStatus;
      } else {
        node.status = null; // Clear status when file is restored to unchanged
      }

      _applyStatuses(node.children, statuses);
    }
  }

  // Expose FAB actions for BrowseScreen to render at screen level
  List<DiffViewerAction> get fabActions {
    if (!mounted) return [];

    final l10n = AppLocalizations.of(context)!;
    final actions = <DiffViewerAction>[];

    if (_selectedNode != null && !_selectedNode!.isDirectory) {
      // Open in Editor (only for files)
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.pencil,
        label: l10n.openInEditor,
        onPressed: () => _openInEditor(_selectedNode!.fullPath),
      ));

      // Rename (F2)
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.textbox,
        label: l10n.rename,
        onPressed: () => _renameFile(context, _selectedNode!.fullPath),
      ));

      // Copy (Ctrl+C)
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.copy,
        label: l10n.copyFile,
        onPressed: () => _copyFile(context, _selectedNode!.fullPath),
      ));

      // Paste (Ctrl+V) - only show if we have something copied
      if (_copiedFilePath != null) {
        actions.add(DiffViewerAction(
          icon: PhosphorIconsRegular.clipboard,
          label: l10n.paste,
          onPressed: () => _pasteFile(context, _selectedNode!.fullPath),
        ));
      }

      // Delete (Del)
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.trash,
        label: l10n.delete,
        onPressed: () => _deleteFile(context, _selectedNode!.fullPath),
      ));

      // Copy Path
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.path,
        label: l10n.labelCopyPath,
        onPressed: () => _copyPath(_selectedNode!.fullPath),
      ));

      // Reveal in Explorer
      actions.add(DiffViewerAction(
        icon: PhosphorIconsRegular.folderOpen,
        label: l10n.labelRevealInExplorer,
        onPressed: () => _revealInExplorer(_selectedNode!.fullPath),
      ));
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    // Watch for branch changes
    final currentBranch = ref.watch(currentBranchProvider).value;

    // If branch changed, reload tree
    if (_previousBranch != null && _previousBranch != currentBranch) {
      _previousBranch = currentBranch;
      // Schedule reload after this build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadFileTree();
        }
      });
    } else {
      _previousBranch ??= currentBranch;
    }

    // Note: Git status changes are handled by ref.listenManual in initState
    // This ensures updates when files are restored/modified externally

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Additional keyboard shortcuts for file operations
    final additionalBindings = <ShortcutActivator, VoidCallback>{
      // F2 - Rename
      const SingleActivator(LogicalKeyboardKey.f2): () {
        if (_selectedNode != null && !_selectedNode!.isDirectory) {
          _renameFile(context, _selectedNode!.fullPath);
        }
      },
      // Ctrl+C - Copy
      const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
        if (_selectedNode != null && !_selectedNode!.isDirectory) {
          _copyFile(context, _selectedNode!.fullPath);
        }
      },
      // Cmd+C - Copy (macOS)
      const SingleActivator(LogicalKeyboardKey.keyC, meta: true): () {
        if (_selectedNode != null && !_selectedNode!.isDirectory) {
          _copyFile(context, _selectedNode!.fullPath);
        }
      },
      // Ctrl+V - Paste
      const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
        if (_selectedNode != null && _copiedFilePath != null) {
          _pasteFile(context, _selectedNode!.fullPath);
        }
      },
      // Cmd+V - Paste (macOS)
      const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
        if (_selectedNode != null && _copiedFilePath != null) {
          _pasteFile(context, _selectedNode!.fullPath);
        }
      },
      // Delete - Delete file
      const SingleActivator(LogicalKeyboardKey.delete): () {
        if (_selectedNode != null && !_selectedNode!.isDirectory) {
          _deleteFile(context, _selectedNode!.fullPath);
        }
      },
    };

    // Main content widget with keyboard navigation
    return GestureDetector(
      onTap: () => _treeController.requestFocus(),
      child: CallbackShortcuts(
        bindings: {
          ..._treeController.keyBindings,
          ...additionalBindings,
        },
        child: Focus(
          focusNode: _treeController.focusNode,
          autofocus: true,
          child: ListenableBuilder(
            listenable: _treeController,
            builder: (context, _) {
              final nodes = _treeController.flattenedNodes;
              if (nodes.isEmpty) {
                return const Center(
                  child: BodyMediumLabel('No files'),
                );
              }
              return ListView.builder(
                controller: _treeController.scrollController,
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  final depth = node.fullPath.split(Platform.pathSeparator).length -
                      widget.repositoryPath.split(Platform.pathSeparator).length;
                  final isSelected = _treeController.isSelected(index);

                  return _buildTreeItem(node, depth, isSelected, index);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Search through all files and folders, loading children as needed
  /// Returns true if any matches were found in this subtree
  Future<bool> _searchAndExpandNodes(List<FileTreeNode> nodes, String query) async {
    final parser = SearchParser(query: query, mode: widget.searchMode);
    bool foundAny = false;

    for (final node in nodes) {
      bool nodeMatches = parser.matches(node.name, node.fullPath);
      bool childrenMatch = false;

      if (node.isDirectory) {
        // Load children if not already loaded
        if (node.children.isEmpty) {
          final children = await _buildTreeNodes(node.fullPath);
          final statusAsync = ref.read(repositoryStatusProvider);
          final statuses = statusAsync.value ?? [];
          _applyStatuses(children, statuses);
          node.children.addAll(children);
        }

        // Recursively search children
        childrenMatch = await _searchAndExpandNodes(node.children, query);

        // Expand folder if it contains matches
        if (childrenMatch) {
          node.isExpanded = true;
        }
      }

      if (nodeMatches || childrenMatch) {
        foundAny = true;
      }
    }

    return foundAny;
  }

  /// Filter nodes to only show matching items and their parent folders
  List<FileTreeNode> _filterNodes(List<FileTreeNode> nodes, String query) {
    final filtered = <FileTreeNode>[];
    final parser = SearchParser(query: query, mode: widget.searchMode);

    for (final node in nodes) {
      final nodeMatches = parser.matches(node.name, node.fullPath);

      if (node.isDirectory) {
        // Check if any children match
        final matchingChildren = _filterNodes(node.children, query);

        if (nodeMatches || matchingChildren.isNotEmpty) {
          // Create a copy of the node with only matching children
          final filteredNode = FileTreeNode(
            name: node.name,
            fullPath: node.fullPath,
            isDirectory: true,
            children: matchingChildren.isNotEmpty ? matchingChildren : node.children,
            isExpanded: true, // Auto-expand folders with matches
            status: node.status,
          );
          filtered.add(filteredNode);
        }
      } else if (nodeMatches) {
        filtered.add(node);
      }
    }

    return filtered;
  }

  Widget _buildTreeItem(FileTreeNode node, int depth, bool isSelected, int index) {
    return BaseTreeItem(
      node: node,
      depth: depth,
      isSelected: isSelected,
      onTap: () {
        _treeController.setSelectedIndex(index);
        _treeController.requestFocus();
      },
      onDoubleTap: node.isDirectory
          ? () {
              _treeController.setSelectedIndex(index);
              _treeController.toggleNodeExpansion(node);
              _treeController.requestFocus();
            }
          : null,
      onExpandToggle: () {
        _treeController.setSelectedIndex(index);
        _treeController.toggleNodeExpansion(node);
        _treeController.requestFocus();
      },
      fileIcon: FileIconUtils.getIconForStatus(node.status),
      fileIconColor: node.status?.color,
      trailingWidget: node.status != null
          ? FileStatusBadge(
              code: node.status!.code,
              color: node.status!.color,
              isSelected: isSelected,
            )
          : null,
    );
  }

  Future<void> _openInEditor(String filePath) async {
    final editor = ref.read(preferredTextEditorProvider);
    if (editor == null || editor.isEmpty) {
      Logger.warning('No text editor configured in settings');
      if (mounted) {
        NotificationService.showWarning(
          context,
          'No text editor configured. Please set a text editor in Settings.',
        );
      }
      return;
    }

    try {
      Logger.info('Opening file in editor: $filePath with editor: $editor');
      await EditorLauncherService.launch(
        editorPath: editor,
        targetPath: filePath,
      );
    } catch (e) {
      Logger.error('Error opening editor: $editor with file: $filePath', e);
      if (mounted) {
        NotificationService.showError(
          context,
          'Failed to open editor: $editor\nFile: $filePath\nError: $e',
        );
      }
    }
  }

  Future<void> _copyPath(String filePath) async {
    await Clipboard.setData(ClipboardData(text: filePath));
  }

  Future<void> _revealInExplorer(String filePath) async {
    try {
      if (Platform.isWindows) {
        // Windows: Normalize path to use backslashes
        final normalizedPath = filePath.replaceAll('/', '\\');

        // Use Process.start to avoid shell interpretation issues
        await Process.start(
          'explorer.exe',
          ['/select,', normalizedPath],
        );
      } else if (Platform.isMacOS) {
        // macOS: Use open -R to reveal in Finder
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        // Linux: Try desktop-specific file managers with file selection
        bool success = false;

        // Try GNOME Files (Nautilus) - Ubuntu default
        try {
          final result = await Process.run('nautilus', ['--select', filePath]);
          if (result.exitCode == 0) {
            success = true;
          }
        } catch (_) {
          // Nautilus not available, try next option
        }

        // Try KDE Dolphin
        if (!success) {
          try {
            final result = await Process.run('dolphin', ['--select', filePath]);
            if (result.exitCode == 0) {
              success = true;
            }
          } catch (_) {
            // Dolphin not available, use fallback
          }
        }

        // Fallback: Just open the containing directory
        if (!success) {
          final dir = p.dirname(filePath);
          await Process.run('xdg-open', [dir]);
        }
      }
    } catch (e) {
      Logger.error('Error revealing file in explorer: $filePath', e);
      if (!mounted) return;
      if (!context.mounted) return;
      NotificationService.showError(
        context,
        'Failed to reveal file in file manager\nFile: $filePath\nError: $e',
      );
    }
  }

  // File Operations

  Future<void> _renameFile(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      final currentName = p.basename(filePath);

      if (!await file.exists()) {
        Logger.warning('Rename operation: file not found: $filePath');
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'File not found\nFile: $filePath',
          );
        }
        return;
      }

      // Show rename dialog
      if (!context.mounted) return;
      final newName = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: currentName);
          return BaseDialog(
            title: AppLocalizations.of(context)!.dialogTitleRenameFile,
            icon: PhosphorIconsRegular.pencilSimple,
            content: BaseTextField(
              controller: controller,
              autofocus: true,
              label: AppLocalizations.of(context)!.dialogLabelNewName,
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            actions: [
              BaseButton(
                label: AppLocalizations.of(context)!.cancel,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context),
              ),
              BaseButton(
                label: AppLocalizations.of(context)!.dialogActionRename,
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.pop(context, controller.text),
              ),
            ],
          );
        },
      );

      if (newName == null || newName.isEmpty || newName == currentName) {
        return;
      }

      // Rename file
      final newPath = p.join(p.dirname(filePath), newName);
      Logger.info('Renaming file: $filePath -> $newPath');
      await file.rename(newPath);

      // Refresh file tree
      await _loadFileTree();
    } catch (e) {
      Logger.error('Failed to rename file: $filePath', e);
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to rename file\nFile: $filePath\nError: $e',
        );
      }
    }
  }

  void _copyFile(BuildContext context, String filePath) {
    setState(() {
      _copiedFilePath = filePath;
    });
  }

  Future<void> _pasteFile(BuildContext context, String targetPath) async {
    if (_copiedFilePath == null) {
      Logger.warning('Paste operation: no file copied');
      NotificationService.showWarning(
        context,
        'No file copied. Please copy a file first.',
      );
      return;
    }

    try {
      final sourceFile = File(_copiedFilePath!);

      if (!await sourceFile.exists()) {
        Logger.warning('Paste operation: source file not found: $_copiedFilePath');
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Source file not found\nFile: $_copiedFilePath',
          );
        }
        return;
      }

      // Determine destination directory
      final targetDir = Directory(targetPath);
      String destinationDirPath;

      if (await targetDir.exists()) {
        // Target is a directory, paste into it
        destinationDirPath = targetPath;
      } else {
        // Target is a file, paste into same directory
        destinationDirPath = p.dirname(targetPath);
      }

      // Get source file info
      final sourceDir = p.dirname(_copiedFilePath!);
      final fileName = p.basename(_copiedFilePath!);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final extension = p.extension(fileName);

      // Check if pasting in the same directory
      final isSameDirectory = p.normalize(sourceDir) == p.normalize(destinationDirPath);

      String destinationPath = p.join(destinationDirPath, fileName);

      // Check if file exists (or if pasting in same directory)
      if (isSameDirectory || await File(destinationPath).exists()) {
        if (context.mounted) {
          final action = await showDialog<String>(
            context: context,
            builder: (context) => BaseDialog(
              title: isSameDirectory ? AppLocalizations.of(context)!.dialogTitleCopyFile : AppLocalizations.of(context)!.dialogTitleFileExists,
              icon: PhosphorIconsRegular.copySimple,
              variant: DialogVariant.confirmation,
              content: BodyMediumLabel(isSameDirectory ? AppLocalizations.of(context)!.dialogContentCopyFileExists(fileName) : AppLocalizations.of(context)!.dialogContentFileExistsDestination(fileName)),
              actions: [
                BaseButton(
                  label: AppLocalizations.of(context)!.cancel,
                  variant: ButtonVariant.tertiary,
                  onPressed: () => Navigator.pop(context, 'cancel'),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.dialogActionKeepBoth,
                  variant: ButtonVariant.tertiary,
                  onPressed: () => Navigator.pop(context, 'keep_both'),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.replace,
                  variant: ButtonVariant.primary,
                  onPressed: () => Navigator.pop(context, 'replace'),
                ),
              ],
            ),
          );

          if (action == null || action == 'cancel') return;

          if (action == 'keep_both') {
            // Generate a unique name for the copy
            destinationPath = _generateCopyName(destinationDirPath, nameWithoutExt, extension);
          } else if (action == 'replace') {
            // If replacing in same directory, delete original first
            if (isSameDirectory) {
              // Can't replace itself, create a copy instead
              destinationPath = _generateCopyName(destinationDirPath, nameWithoutExt, extension);
            }
            // Otherwise destinationPath stays the same for overwrite
          }
        }
      }

      // Copy file
      Logger.info('Pasting file: $_copiedFilePath -> $destinationPath');
      await sourceFile.copy(destinationPath);

      // Refresh file tree
      await _loadFileTree();
    } catch (e) {
      Logger.error('Failed to paste file: $_copiedFilePath -> $targetPath', e);
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to paste file\nSource: $_copiedFilePath\nDestination: $targetPath\nError: $e',
        );
      }
    }
  }

  /// Generate a unique copy name like Windows Explorer
  /// Examples: "file - Copy.txt", "file (2).txt", "file (3).txt"
  String _generateCopyName(String dirPath, String nameWithoutExt, String extension) {
    // Try "filename - Copy.ext" first
    String tryPath = p.join(dirPath, '$nameWithoutExt - Copy$extension');
    if (!File(tryPath).existsSync()) {
      return tryPath;
    }

    // Try "filename (2).ext", "filename (3).ext", etc.
    int counter = 2;
    while (true) {
      tryPath = p.join(dirPath, '$nameWithoutExt ($counter)$extension');
      if (!File(tryPath).existsSync()) {
        return tryPath;
      }
      counter++;

      // Safety check to avoid infinite loop
      if (counter > 1000) {
        // Fallback to timestamp-based name
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        return p.join(dirPath, '$nameWithoutExt - $timestamp$extension');
      }
    }
  }

  Future<void> _deleteFile(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      final fileName = p.basename(filePath);

      if (!await file.exists()) {
        Logger.warning('Delete operation: file not found: $filePath');
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'File not found\nFile: $filePath',
          );
        }
        return;
      }

      // Confirm deletion
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => BaseDialog(
            icon: PhosphorIconsRegular.warning,
            title: AppLocalizations.of(context)!.dialogTitleDeleteFile,
            variant: DialogVariant.destructive,
            content: BodyMediumLabel(AppLocalizations.of(context)!.dialogContentDeleteFile(fileName)),
            actions: [
              BaseButton(
                label: AppLocalizations.of(context)!.cancel,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context, false),
              ),
              BaseButton(
                label: AppLocalizations.of(context)!.delete,
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // Delete file
      Logger.info('Deleting file: $filePath');
      await file.delete();

      // Refresh file tree
      await _loadFileTree();
    } catch (e) {
      Logger.error('Failed to delete file: $filePath', e);
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to delete file\nFile: $filePath\nError: $e',
        );
      }
    }
  }
}
