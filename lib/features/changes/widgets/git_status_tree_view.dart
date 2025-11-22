import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_diff_viewer.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/controllers/tree_view_controller.dart';
import '../../../shared/widgets/base_tree_item.dart';
import '../../../shared/widgets/file_status_badge.dart';
import '../../../core/git/models/file_status.dart';
import '../../../core/diff/diff_parser.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/diff/diff_providers.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../generated/app_localizations.dart';
import '../../../shared/dialogs/blame_dialog.dart';

/// Tree node for git status display
class GitStatusTreeNode with TreeNodeMixin {
  @override
  final String name;
  @override
  final String fullPath;
  @override
  final bool isDirectory;
  @override
  final List<GitStatusTreeNode> children;
  final FileStatus? fileStatus; // null for directories
  @override
  bool isExpanded;

  GitStatusTreeNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    List<GitStatusTreeNode>? children,
    this.fileStatus,
    this.isExpanded = true, // Expand directories by default
  }) : children = children ?? [];

  /// Check if this file is staged
  bool get isStaged => fileStatus?.isStaged ?? false;
}

/// Unified tree view for git changes - shows both staged and unstaged files in one tree
class GitStatusTreeView extends ConsumerStatefulWidget {
  final List<FileStatus> stagedFiles;
  final List<FileStatus> unstagedFiles;
  final Function(FileStatus file, bool currentlyStaged)? onToggleStage;
  final Function(FileStatus file)? onDiscardFile;
  final Function(FileStatus file)? onDeleteFile;

  const GitStatusTreeView({
    super.key,
    required this.stagedFiles,
    required this.unstagedFiles,
    this.onToggleStage,
    this.onDiscardFile,
    this.onDeleteFile,
  });

  @override
  ConsumerState<GitStatusTreeView> createState() => _GitStatusTreeViewState();
}

class _GitStatusTreeViewState extends ConsumerState<GitStatusTreeView> {
  List<GitStatusTreeNode> _rootNodes = [];
  late final TreeViewController<GitStatusTreeNode> _treeController;
  DiffViewMode _diffViewMode = DiffViewMode.diff;

  @override
  void initState() {
    super.initState();
    _treeController = TreeViewController<GitStatusTreeNode>(
      itemHeight: 32.0,
      skipDirectories: true, // Skip directories when navigating
      onSelectionChanged: (node) {
        // Trigger rebuild to update diff panel
        setState(() {});
      },
    );
    _buildTree();
  }

  @override
  void didUpdateWidget(GitStatusTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stagedFiles != widget.stagedFiles ||
        oldWidget.unstagedFiles != widget.unstagedFiles) {
      _buildTree();
    }
  }

  @override
  void dispose() {
    _treeController.dispose();
    super.dispose();
  }

  void _buildTree() {
    // Combine all files (both staged and unstaged)
    final allFiles = <FileStatus>[
      ...widget.stagedFiles,
      ...widget.unstagedFiles,
    ];

    // Remove duplicates (same file can be in both lists)
    final uniqueFiles = <String, FileStatus>{};
    for (final file in allFiles) {
      uniqueFiles[file.path] = file;
    }

    // Build tree structure - use a different approach
    // Build a tree from paths by recursively creating directory nodes
    final root = <String, dynamic>{};

    // First pass: build the tree structure
    for (final file in uniqueFiles.values) {
      final parts = file.path.split('/');
      dynamic currentLevel = root;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isLastPart = i == parts.length - 1;

        if (!currentLevel.containsKey(part)) {
          if (isLastPart) {
            // Leaf node - store the FileStatus
            currentLevel[part] = file;
          } else {
            // Directory node - create a new map
            currentLevel[part] = <String, dynamic>{};
          }
        }

        if (!isLastPart) {
          currentLevel = currentLevel[part];
        }
      }
    }

    // Second pass: convert the tree structure to GitStatusTreeNode objects
    List<GitStatusTreeNode> convertToNodes(Map<String, dynamic> map, String parentPath) {
      final nodes = <GitStatusTreeNode>[];

      for (final entry in map.entries) {
        final name = entry.key;
        final value = entry.value;
        final fullPath = parentPath.isEmpty ? name : '$parentPath/$name';

        if (value is FileStatus) {
          // This is a file
          nodes.add(GitStatusTreeNode(
            name: name,
            fullPath: fullPath,
            isDirectory: false,
            children: const [],
            fileStatus: value,
          ));
        } else if (value is Map<String, dynamic>) {
          // This is a directory
          final children = convertToNodes(value, fullPath);
          nodes.add(GitStatusTreeNode(
            name: name,
            fullPath: fullPath,
            isDirectory: true,
            children: children,
            fileStatus: null,
          ));
        }
      }

      return nodes;
    }

    _rootNodes = convertToNodes(root, '');

    // Sort nodes
    _rootNodes = _sortNodes(_rootNodes);

    // Update tree controller - this handles flattening and selection validation
    _treeController.updateNodes(_rootNodes);

    setState(() {});
  }

  List<GitStatusTreeNode> _sortNodes(List<GitStatusTreeNode> nodes) {
    final sorted = <GitStatusTreeNode>[];

    for (final node in nodes) {
      if (node.isDirectory && node.children.isNotEmpty) {
        // Recursively sort children for directories
        final sortedChildren = _sortNodes(node.children);
        sorted.add(GitStatusTreeNode(
          name: node.name,
          fullPath: node.fullPath,
          isDirectory: node.isDirectory,
          children: sortedChildren,
          fileStatus: node.fileStatus,
          isExpanded: node.isExpanded,
        ));
      } else {
        // Files or empty directories - no sorting needed for children
        sorted.add(node);
      }
    }

    // Sort at this level: directories first, then alphabetically
    sorted.sort((a, b) {
      // Directories first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      // Then alphabetically
      return a.name.compareTo(b.name);
    });

    return sorted;
  }

  FileStatus? get _selectedFile {
    final node = _treeController.selectedNode;
    return node?.fileStatus;
  }

  void _toggleSelectedNode() {
    final node = _treeController.selectedNode;
    if (node == null) return;

    if (node.isDirectory) {
      // Toggle directory expansion via controller
      _treeController.toggleNodeExpansion(node);
    } else if (node.fileStatus != null) {
      // Toggle file staging
      widget.onToggleStage?.call(node.fileStatus!, node.isStaged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flattenedNodes = _treeController.flattenedNodes;

    if (flattenedNodes.isEmpty) {
      return const Center(
        child: BodyMediumLabel('No changes'),
      );
    }

    return GestureDetector(
      onTap: () {
        // Request focus when clicked
        _treeController.requestFocus();
      },
      child: CallbackShortcuts(
        bindings: {
          ..._treeController.keyBindings,
          // Override space/enter to toggle staging instead of just expanding
          const SingleActivator(LogicalKeyboardKey.space): _toggleSelectedNode,
          const SingleActivator(LogicalKeyboardKey.enter): _toggleSelectedNode,
        },
        child: Focus(
          focusNode: _treeController.focusNode,
          autofocus: true,
          skipTraversal: false,
          canRequestFocus: true,
          child: Row(
            children: [
              // Left panel: File tree
              Expanded(
                flex: 1,
                child: BasePanel(
                  title: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.tree,
                        size: AppTheme.iconS,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      const TitleSmallLabel('Changed Files'),
                    ],
                  ),
                  padding: EdgeInsets.zero,
                  content: ListenableBuilder(
                    listenable: _treeController,
                    builder: (context, _) {
                      final nodes = _treeController.flattenedNodes;
                      return ListView.builder(
                        controller: _treeController.scrollController,
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          final depth = node.fullPath.split('/').length - 1;
                          final isSelected = _treeController.isSelected(index);

                          return _buildTreeItem(node, depth, isSelected, index);
                        },
                      );
                    },
                  ),
                ),
              ),

            // Right panel: Diff viewer
            if (_selectedFile != null)
              Expanded(
                flex: 2,
                child: BasePanel(
                  title: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.gitDiff,
                        size: AppTheme.iconS,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      Expanded(
                        child: TitleSmallLabel(
                          _selectedFile!.path,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _selectedFile!.isStaged
                            ? PhosphorIconsBold.checkSquare
                            : PhosphorIconsRegular.square,
                        size: AppTheme.iconS,
                        color: _selectedFile!.isStaged
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.paddingXS),
                      BodySmallLabel(
                        _selectedFile!.isStaged ? 'Staged' : 'Unstaged',
                      ),
                    ],
                  ),
                  padding: EdgeInsets.zero,
                  content: _DiffViewerPanel(
                    key: ValueKey('${_selectedFile!.path}_${_selectedFile!.isStaged}_$_diffViewMode'),
                    filePath: _selectedFile!.path,
                    staged: _selectedFile!.isStaged,
                    viewMode: _diffViewMode,
                    fileStatus: _selectedFile!,
                    onToggleViewMode: () {
                      setState(() {
                        _diffViewMode = _diffViewMode == DiffViewMode.diff
                            ? DiffViewMode.fullFile
                            : DiffViewMode.diff;
                      });
                    },
                    onDiscardFile: widget.onDiscardFile != null
                        ? () => widget.onDiscardFile!(_selectedFile!)
                        : null,
                    onToggleStage: widget.onToggleStage != null
                        ? () => widget.onToggleStage!(_selectedFile!, _selectedFile!.isStaged)
                        : null,
                    onDeleteFile: _selectedFile!.primaryStatus == FileStatusType.untracked && widget.onDeleteFile != null
                        ? () => widget.onDeleteFile!(_selectedFile!)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTreeItem(GitStatusTreeNode node, int depth, bool isSelected, int index) {
    // Get color based on file status
    Color? fileColor;
    if (node.fileStatus != null) {
      final statusType = node.fileStatus!.primaryStatus;
      fileColor = statusType.color;
    }

    return BaseTreeItem(
      node: node,
      depth: depth,
      isSelected: isSelected,
      indentPerLevel: AppTheme.paddingM,
      onTap: () {
        if (node.isDirectory) {
          _treeController.toggleNodeExpansion(node);
        } else {
          _treeController.setSelectedIndex(index);
        }
        _treeController.requestFocus();
      },
      onDoubleTap: (!node.isDirectory && node.fileStatus != null)
          ? () {
              widget.onToggleStage?.call(node.fileStatus!, node.isStaged);
            }
          : null,
      leadingWidget: !node.isDirectory
          ? Icon(
              node.isStaged
                  ? PhosphorIconsBold.checkSquare
                  : PhosphorIconsRegular.square,
              size: AppTheme.iconS,
              color: node.isStaged
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      fileIconColor: fileColor,
      trailingWidget: (!node.isDirectory && node.fileStatus != null)
          ? FileStatusBadge(
              code: node.fileStatus!.primaryStatus.code,
              color: node.fileStatus!.primaryStatus.color,
              isSelected: isSelected,
            )
          : null,
    );
  }
}

/// Diff viewer panel widget
class _DiffViewerPanel extends ConsumerStatefulWidget {
  final String filePath;
  final bool staged;
  final DiffViewMode viewMode;
  final VoidCallback onToggleViewMode;
  final FileStatus fileStatus;
  final VoidCallback? onDiscardFile;
  final VoidCallback? onToggleStage;
  final VoidCallback? onDeleteFile;

  const _DiffViewerPanel({
    super.key,
    required this.filePath,
    required this.staged,
    required this.viewMode,
    required this.onToggleViewMode,
    required this.fileStatus,
    this.onDiscardFile,
    this.onToggleStage,
    this.onDeleteFile,
  });

  @override
  ConsumerState<_DiffViewerPanel> createState() => _DiffViewerPanelState();
}

class _DiffViewerPanelState extends ConsumerState<_DiffViewerPanel> {
  late bool _compactMode;
  late Future<Map<String, String?>> _diffFuture;

  @override
  void initState() {
    super.initState();
    // Initialize compact mode from config
    _compactMode = ref.read(configProvider).ui.diffCompactMode;
    // Cache the future to prevent reloading on every rebuild
    _diffFuture = _loadDiffAndContent();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _diffFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: AppTheme.iconXL,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppTheme.paddingM),
                BodyMediumLabel(
                  'Error loading diff: ${snapshot.error}',
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
          );
        }

        // Show diff immediately if available, otherwise show empty state
        // This prevents blocking the UI while loading
        final data = snapshot.data ?? {};
        final diffOutput = data['diff'] ?? '';
        final fullFileContent = data['fullContent'];

        if (diffOutput.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          // Still loading, show minimal placeholder
          return const Center(
            child: SizedBox(
              width: AppTheme.iconM,
              height: AppTheme.iconM,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final diffLines = DiffParser.parse(diffOutput);
        final l10n = AppLocalizations.of(context)!;
        final diffTool = ref.watch(selectedDiffToolProvider);

        // Build additional actions for the FAB
        final additionalActions = <DiffViewerAction>[
          // Stage/Unstage action
          if (widget.onToggleStage != null)
            DiffViewerAction(
              icon: widget.staged
                  ? PhosphorIconsRegular.minus
                  : PhosphorIconsRegular.plus,
              label: widget.staged ? l10n.unstageAll : l10n.stageAll,
              onPressed: widget.onToggleStage!,
            ),
          // Discard changes action (for modified/deleted files)
          if (widget.onDiscardFile != null &&
              widget.fileStatus.primaryStatus != FileStatusType.untracked)
            DiffViewerAction(
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              label: l10n.discardChangesQuestion,
              onPressed: widget.onDiscardFile!,
            ),
          // Delete file action (for untracked files)
          if (widget.onDeleteFile != null &&
              widget.fileStatus.primaryStatus == FileStatusType.untracked)
            DiffViewerAction(
              icon: PhosphorIconsRegular.trash,
              label: l10n.delete,
              onPressed: widget.onDeleteFile!,
            ),
          // Copy all content action
          DiffViewerAction(
            icon: PhosphorIconsRegular.copy,
            label: l10n.labelCopyAll,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diffOutput));
              if (context.mounted) {
                NotificationService.showSuccess(context, l10n.snackbarDiffCopied);
              }
            },
          ),
          // Open in external tool action (if available)
          if (diffTool != null)
            DiffViewerAction(
              icon: PhosphorIconsRegular.arrowSquareOut,
              label: l10n.labelOpenInExternalTool,
              onPressed: () async {
                try {
                  Logger.info('Opening external diff tool for file: ${widget.filePath}, staged: ${widget.staged}');
                  if (widget.staged) {
                    await ref.read(diffActionsProvider).diffStagedFile(widget.filePath);
                  } else {
                    await ref.read(diffActionsProvider).diffUnstagedFile(widget.filePath);
                  }
                } catch (e) {
                  Logger.error('Failed to open external diff tool for file: ${widget.filePath}', e);
                  if (context.mounted) {
                    NotificationService.showError(
                      context,
                      'Failed to open external diff tool\nFile: ${widget.filePath}\nError: $e',
                    );
                  }
                }
              },
            ),
          // Blame action (show who changed each line)
          DiffViewerAction(
            icon: PhosphorIconsRegular.userList,
            label: l10n.blame,
            onPressed: () {
              showBlameDialog(
                context,
                filePath: widget.filePath,
              );
            },
          ),
        ];

        return BaseDiffViewer(
          diffLines: diffLines,
          compactMode: _compactMode,
          showLineNumbers: true,
          fullFileContent: fullFileContent,
          filePath: widget.filePath,
          viewMode: widget.viewMode,
          onToggleViewMode: widget.onToggleViewMode,
          additionalActions: additionalActions,
          fontFamily: ref.watch(previewFontFamilyProvider),
          fontSize: ref.watch(previewFontSizeProvider),
        );
      },
    );
  }

  Future<Map<String, String?>> _loadDiffAndContent() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) {
      throw Exception('No repository open');
    }

    String diff = await gitService.getDiff(widget.filePath, staged: widget.staged);
    String? fullContent;

    // Try to load full file content
    try {
      fullContent = await gitService.getFileContent(widget.filePath);
      Logger.debug('[TreeView] getFileContent(${widget.filePath}) returned: ${fullContent?.length ?? 0} chars');
      Logger.debug('[TreeView] diff.isEmpty=${diff.isEmpty}, diff.trim().isEmpty=${diff.trim().isEmpty}');
      Logger.debug('[TreeView] fullContent != null: ${fullContent != null}, fullContent.isNotEmpty: ${fullContent?.isNotEmpty ?? false}');

      // If diff is empty but we have file content, this is likely an untracked file
      // Generate a synthetic diff showing all content as additions
      if ((diff.isEmpty || diff.trim().isEmpty) && fullContent != null && fullContent.isNotEmpty) {
        Logger.debug('[TreeView] Generating synthetic diff for ${widget.filePath}');
        diff = _generateSyntheticDiff(widget.filePath, fullContent);
        Logger.debug('[TreeView] Generated synthetic diff length: ${diff.length}');
      }
    } catch (e) {
      // If we can't get file content, it's okay - we'll just show the diff
      Logger.debug('[TreeView] Error loading file content for ${widget.filePath}: $e');
      fullContent = null;
    }

    return {
      'diff': diff,
      'fullContent': fullContent,
    };
  }

  /// Generate a synthetic diff for untracked files showing all content as additions
  String _generateSyntheticDiff(String filePath, String content) {
    final lines = content.split('\n');
    final buffer = StringBuffer();

    // Add diff header
    buffer.writeln('diff --git a/$filePath b/$filePath');
    buffer.writeln('new file mode 100644');
    buffer.writeln('--- /dev/null');
    buffer.writeln('+++ b/$filePath');
    buffer.writeln('@@ -0,0 +1,${lines.length} @@');

    // Add all lines as additions
    for (final line in lines) {
      buffer.writeln('+$line');
    }

    return buffer.toString();
  }
}
