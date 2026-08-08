import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_diff_viewer.dart';
import '../../../shared/components/base_speed_dial.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/controllers/tree_view_controller.dart';
import '../../../shared/widgets/base_focus_region.dart';
import '../../../shared/widgets/base_tree_item.dart';
import '../../../shared/widgets/keyboard_navigable_view.dart';
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

  /// Check if this file has staged and unstaged changes at the same time
  bool get isPartiallyStaged => fileStatus?.isPartiallyStaged ?? false;

  /// Check if this file has no changes left outside the index
  bool get isFullyStaged => fileStatus?.isFullyStaged ?? false;
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
      // Enter/Space on the highlighted file toggles staging; the shared tree
      // view routes activation here. A partially staged file counts as not
      // staged, so toggling adds its remaining work tree changes instead of
      // unstaging the half that is already in the index.
      onToggleNode: (node) {
        if (node.fileStatus != null) {
          widget.onToggleStage?.call(node.fileStatus!, node.isFullyStaged);
        }
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
    List<GitStatusTreeNode> convertToNodes(
      Map<String, dynamic> map,
      String parentPath,
    ) {
      final nodes = <GitStatusTreeNode>[];

      for (final entry in map.entries) {
        final name = entry.key;
        final value = entry.value;
        final fullPath = parentPath.isEmpty ? name : '$parentPath/$name';

        if (value is FileStatus) {
          // This is a file
          nodes.add(
            GitStatusTreeNode(
              name: name,
              fullPath: fullPath,
              isDirectory: false,
              children: const [],
              fileStatus: value,
            ),
          );
        } else if (value is Map<String, dynamic>) {
          // This is a directory
          final children = convertToNodes(value, fullPath);
          nodes.add(
            GitStatusTreeNode(
              name: name,
              fullPath: fullPath,
              isDirectory: true,
              children: children,
              fileStatus: null,
            ),
          );
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
        sorted.add(
          GitStatusTreeNode(
            name: node.name,
            fullPath: node.fullPath,
            isDirectory: node.isDirectory,
            children: sortedChildren,
            fileStatus: node.fileStatus,
            isExpanded: node.isExpanded,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final flattenedNodes = _treeController.flattenedNodes;

    if (flattenedNodes.isEmpty) {
      return Center(
        child: BaseLabel(
          AppLocalizations.of(context)!.noChanges,
          role: TextRole.body,
        ),
      );
    }

    // The tree and the diff are regions 2 and 3 of the changes screen's
    // ordered focus walk (the quick-actions bar is 1, the commit bar 4);
    // they are declared here because this widget owns the split.
    return Row(
      children: [
        // Left panel: File tree. The navigable view owns key handling on the
        // tree's own focus node only — never on this Row — so focusable
        // children in the diff panel beside it keep their arrow keys instead
        // of having them swallowed by tree navigation.
        Expanded(
          flex: 1,
          child: BaseFocusRegion(
            order: 2,
            debugLabel: 'ChangesScreen.treeRegion',
            child: BasePanel(
              title: Row(
                children: [
                  // The panel header's mark: a dense header glyph carrying the
                  // application's own colour, which is `compact` and
                  // `Tone.accent`.
                  const BaseIcon(
                    IconRole.tree,
                    scale: ControlScale.compact,
                    tone: Tone.accent,
                  ),
                  const BaseGap(Proximity.related),
                  // Flexible, because a section title is a rung larger than
                  // the panel header used to be and this pane is one third of
                  // the window: at the 800 px minimum the application allows
                  // (AppConstants.minWindowWidth) an unflexed title overflows
                  // its header instead of truncating. The diff panel's title
                  // beside it already says the same thing.
                  const Flexible(
                    child: BaseLabel(
                      'Changed Files',
                      role: TextRole.sectionTitle,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              inset: Inset.none,
              content: KeyboardNavigableTreeView<GitStatusTreeNode>(
                controller: _treeController,
                autofocus: true,
                itemBuilder:
                    (context, node, depth, isSelected, containerHasFocus) =>
                        _buildTreeItem(
                          node,
                          depth,
                          isSelected,
                          containerHasFocus,
                        ),
              ),
            ),
          ),
        ),

        // Right panel: Diff viewer
        if (_selectedFile != null)
          Expanded(
            flex: 2,
            child: BaseFocusRegion(
              order: 3,
              debugLabel: 'ChangesScreen.diffRegion',
              child: BasePanel(
                title: Row(
                  children: [
                    const BaseIcon(
                      IconRole.gitDiff,
                      scale: ControlScale.compact,
                      tone: Tone.accent,
                    ),
                    const BaseGap(Proximity.related),
                    Expanded(
                      // The name of one object - the file whose diff is
                      // on screen - rather than the name of the region.
                      child: BaseLabel(
                        _selectedFile!.path,
                        role: TextRole.itemTitle,
                        maxLines: 1,
                      ),
                    ),
                    // How much of this file is in the index, as a mark. The
                    // ticked and the dashed box are drawn BOLD on purpose -
                    // the weight census (icon_weight_census_test.dart) records
                    // this file as one of the surfaces still waiting to be
                    // answered with `MaterialGlyphs.boldOf` when the tree
                    // migrates - and a weight is the one thing `IconRole`
                    // deliberately cannot carry, so the mark stays a raw
                    // `Icon` naming Phosphor's bold constant until the status
                    // tree becomes a member and the skin re-decides the
                    // weight on its side of the seam. Its colour is stranded
                    // with it: a `Tone` can only reach a mark through
                    // `BaseIcon`, which cannot say the weight.
                    Icon(
                      _selectedFile!.isPartiallyStaged
                          ? PhosphorIconsBold.minusSquare
                          : _selectedFile!.isStaged
                          ? PhosphorIconsBold.checkSquare
                          : PhosphorIconsRegular.square,
                      size: AppTheme.iconS,
                      color: _selectedFile!.isStaged
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    // A mark and the word beside it are two halves of one
                    // thing: `hairline`.
                    const BaseGap(Proximity.hairline),
                    BaseLabel(
                      _selectedFile!.isPartiallyStaged
                          ? 'Partially staged'
                          : _selectedFile!.isStaged
                          ? 'Staged'
                          : 'Unstaged',
                      role: TextRole.detail,
                    ),
                  ],
                ),
                inset: Inset.none,
                content: _DiffViewerPanel(
                  key: ValueKey(
                    '${_selectedFile!.path}_${_selectedFile!.isFullyStaged}_$_diffViewMode',
                  ),
                  filePath: _selectedFile!.path,
                  // A partially staged file shows its work tree half, because that
                  // is the part the user can otherwise neither see nor stage here.
                  staged: _selectedFile!.isFullyStaged,
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
                      ? () => widget.onToggleStage!(
                          _selectedFile!,
                          _selectedFile!.isFullyStaged,
                        )
                      : null,
                  onDeleteFile:
                      _selectedFile!.primaryStatus ==
                              FileStatusType.untracked &&
                          widget.onDeleteFile != null
                      ? () => widget.onDeleteFile!(_selectedFile!)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTreeItem(
    GitStatusTreeNode node,
    int depth,
    bool isSelected,
    bool containerHasFocus,
  ) {
    // Get color based on file status
    Color? fileColor;
    if (node.fileStatus != null) {
      final statusType = node.fileStatus!.primaryStatus;
      fileColor = statusType.colorOf(context);
    }

    return BaseTreeItem(
      node: node,
      depth: depth,
      isSelected: isSelected,
      containerHasFocus: containerHasFocus,
      // One level of nesting, which is a `Proximity` and not a length - but
      // `BaseTreeItem` still takes a number here, so the rung cannot be stated
      // until that component's own parameter becomes one.
      indentPerLevel: AppTheme.paddingM,
      onTap: () {
        // The navigable view's own listener claims keyboard focus on the
        // press; selection only has to follow the tap.
        if (node.isDirectory) {
          _treeController.toggleNodeExpansion(node);
        } else {
          _treeController.selectByPath(node.fullPath);
        }
      },
      onDoubleTap: (!node.isDirectory && node.fileStatus != null)
          ? () {
              widget.onToggleStage?.call(node.fileStatus!, node.isFullyStaged);
            }
          : null,
      // The same statement one pane over: how much of this file is in the
      // index, as a dense row-level mark. Bold for the same reason the panel
      // header's mark above is: the weight is deliberate, the census guards
      // it, and only the skin can carry it across the seam once the tree is
      // a member.
      leadingWidget: !node.isDirectory
          ? Icon(
              node.isPartiallyStaged
                  ? PhosphorIconsBold.minusSquare
                  : node.isStaged
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
              color: node.fileStatus!.primaryStatus.colorOf(context),
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
                // The headline mark of a failure that fills this pane, and it
                // stays a raw `Icon` for three reasons now. It is not the
                // empty-state facade's shape (#430): a 32 dp mark over one
                // sentence with no headline, where `EmptyStateWidget` draws a
                // 64 dp hero and always renders a `pageTitle` above its
                // message. The facade could not carry the colour even if the
                // shape matched, because it has no tone slot for its hero and
                // would grey this failure out. And `Tone.danger` is not the
                // word for it either - danger means "this destroys something
                // you cannot get back", which a diff that failed to load is
                // not saying. None of the three is rounded onto its nearest
                // neighbour.
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: AppTheme.iconXL,
                  color: Theme.of(context).colorScheme.error,
                ),
                const BaseGap(Proximity.grouped),
                BaseLabel(
                  'Error loading diff: ${snapshot.error}',
                  role: TextRole.body,
                  tone: Tone.danger,
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

        if (diffOutput.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
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
        final additionalActions = <SpeedDialAction>[
          // Stage/Unstage action
          if (widget.onToggleStage != null)
            SpeedDialAction(
              icon: widget.staged
                  ? PhosphorIconsRegular.minus
                  : PhosphorIconsRegular.plus,
              label: widget.staged ? l10n.unstageAll : l10n.stageAll,
              onPressed: widget.onToggleStage!,
            ),
          // Discard changes action (for modified/deleted files)
          if (widget.onDiscardFile != null &&
              widget.fileStatus.primaryStatus != FileStatusType.untracked)
            SpeedDialAction(
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              label: l10n.discardChangesQuestion,
              onPressed: widget.onDiscardFile!,
            ),
          // Delete file action (for untracked files)
          if (widget.onDeleteFile != null &&
              widget.fileStatus.primaryStatus == FileStatusType.untracked)
            SpeedDialAction(
              icon: PhosphorIconsRegular.trash,
              label: l10n.delete,
              onPressed: widget.onDeleteFile!,
            ),
          // Copy all content action
          SpeedDialAction(
            icon: PhosphorIconsRegular.copy,
            label: l10n.labelCopyAll,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diffOutput));
              if (context.mounted) {
                NotificationService.showSuccess(
                  context,
                  l10n.snackbarDiffCopied,
                );
              }
            },
          ),
          // Open in external tool action (if available)
          if (diffTool != null)
            SpeedDialAction(
              icon: PhosphorIconsRegular.arrowSquareOut,
              label: l10n.labelOpenInExternalTool,
              onPressed: () async {
                try {
                  Logger.info(
                    'Opening external diff tool for file: ${widget.filePath}, staged: ${widget.staged}',
                  );
                  if (widget.staged) {
                    await ref
                        .read(diffActionsProvider)
                        .diffStagedFile(widget.filePath);
                  } else {
                    await ref
                        .read(diffActionsProvider)
                        .diffUnstagedFile(widget.filePath);
                  }
                } catch (e) {
                  Logger.error(
                    'Failed to open external diff tool for file: ${widget.filePath}',
                    e,
                  );
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
          SpeedDialAction(
            icon: PhosphorIconsRegular.userList,
            label: l10n.blame,
            onPressed: () {
              showBlameDialog(context, filePath: widget.filePath);
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

    final diffResult = await gitService.getDiff(
      widget.filePath,
      staged: widget.staged,
    );
    String diff = diffResult.unwrap();
    String? fullContent;

    // Try to load full file content
    try {
      fullContent = await gitService.getFileContent(widget.filePath);
      Logger.debug(
        '[TreeView] getFileContent(${widget.filePath}) returned: ${fullContent?.length ?? 0} chars',
      );
      Logger.debug(
        '[TreeView] diff.isEmpty=${diff.isEmpty}, diff.trim().isEmpty=${diff.trim().isEmpty}',
      );
      Logger.debug(
        '[TreeView] fullContent != null: ${fullContent != null}, fullContent.isNotEmpty: ${fullContent?.isNotEmpty ?? false}',
      );

      // If diff is empty but we have file content, this is likely an untracked file
      // Generate a synthetic diff showing all content as additions
      if ((diff.isEmpty || diff.trim().isEmpty) &&
          fullContent != null &&
          fullContent.isNotEmpty) {
        Logger.debug(
          '[TreeView] Generating synthetic diff for ${widget.filePath}',
        );
        diff = _generateSyntheticDiff(widget.filePath, fullContent);
        Logger.debug(
          '[TreeView] Generated synthetic diff length: ${diff.length}',
        );
      }
    } catch (e) {
      // If we can't get file content, it's okay - we'll just show the diff
      Logger.debug(
        '[TreeView] Error loading file content for ${widget.filePath}: $e',
      );
      fullContent = null;
    }

    return {'diff': diff, 'fullContent': fullContent};
  }

  /// Generate a synthetic diff for untracked files showing all content as additions
  String _generateSyntheticDiff(String filePath, String content) {
    final lines = content.split('\n');
    // A file ending in a newline yields a trailing empty element that is not a
    // real line; keeping it would inflate the hunk count by one and render a
    // phantom added line.
    if (lines.length > 1 && lines.last.isEmpty) {
      lines.removeLast();
    }
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
