import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        ControlScale,
        IconRole,
        Inset,
        MenuAction,
        MenuEntry,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone,
        TreeNodeSpec,
        TreeSpec;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_progress.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/widgets/diff_stat_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/utils/file_icon_utils.dart';
import '../../../core/git/models/file_change.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/widgets/commit_file_diff_dialog.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/editor_launcher_service.dart';
import '../../../core/services/notification_service.dart';
import '../providers/commit_diff_provider.dart';

/// Tree node representing a file or directory
class FileTreeNode with TreeNodeMixin {
  @override
  final String name;
  @override
  final String fullPath;
  @override
  final bool isDirectory;
  final FileChange? fileChange; // null for directories
  @override
  final List<FileTreeNode> children;
  @override
  bool isExpanded;

  FileTreeNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    this.fileChange,
    List<FileTreeNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];
}

/// Panel showing changed files in a tree structure
class FileTreePanel extends ConsumerStatefulWidget {
  final String commitHash;

  const FileTreePanel({super.key, required this.commitHash});

  @override
  ConsumerState<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends ConsumerState<FileTreePanel> {
  /// Directories the user has folded shut, by path.
  ///
  /// Expansion is application state under `surfaces.tree` - the member walks
  /// `roots` against it on every build - and holding it HERE is what made the
  /// fold work at all: the hand-rolled rows kept an `isExpanded` flag on node
  /// objects that were rebuilt from the provider on the very setState the
  /// fold triggered, so a collapse never survived its own rebuild.
  final Set<String> _collapsed = <String>{};

  @override
  void didUpdateWidget(FileTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new commit is a new tree, and it opens fully, as it always has.
    if (oldWidget.commitHash != widget.commitHash) _collapsed.clear();
  }

  @override
  Widget build(BuildContext context) {
    final changedFilesAsync = ref.watch(
      commitChangedFilesProvider(widget.commitHash),
    );
    // Watched once for the whole list. Doing it per row subscribed every node
    // to this provider, so each of its loading/data transitions rebuilt the
    // entire tree.
    final displayedPath = ref
        .watch(displayedCommitFileProvider(widget.commitHash))
        .value;

    return BasePanel(
      title: Row(
        children: [
          // A panel header's mark: dense, carrying the application's own
          // colour rather than Material's `primary` slot.
          const BaseIcon(
            IconRole.tree,
            scale: ControlScale.compact,
            tone: Tone.accent,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.labelChangedFiles,
            role: TextRole.sectionTitle,
          ),
        ],
      ),
      inset: Inset.none,
      content: changedFilesAsync.when(
        data: (files) {
          if (files.isEmpty) {
            // Still not the region-scale hero (#430) — this is a pane inside
            // a panel its own header already names — but no longer
            // hand-rolled either: `PanelNote` IS that shape, and adopting it
            // deletes the mark's size and its colour together.
            return PanelNote(
              icon: PhosphorIconsRegular.files,
              message: AppLocalizations.of(context)!.messageNoFilesChanged,
            );
          }

          final stats = FileChangeStats(files);
          final tree = _buildFileTree(files);

          return Column(
            children: [
              // Statistics bar
              Container(
                // The bar's fill and its rule stay: they are the surface.
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: BaseInset(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatChip(
                            context,
                            IconRole.plusCircle,
                            stats.addedFiles.toString(),
                            Tone.gitAdded,
                          ),
                          const BaseGap(Proximity.grouped),
                          _buildStatChip(
                            context,
                            IconRole.pencilSimple,
                            stats.modifiedFiles.toString(),
                            Tone.gitModified,
                          ),
                          const BaseGap(Proximity.grouped),
                          _buildStatChip(
                            context,
                            IconRole.minusCircle,
                            stats.deletedFiles.toString(),
                            Tone.gitDeleted,
                          ),
                        ],
                      ),
                      const BaseGap(Proximity.related),
                      Row(
                        children: [
                          BaseLabel(
                            '${stats.totalFiles} ${stats.totalFiles == 1 ? AppLocalizations.of(context)!.labelFile : AppLocalizations.of(context)!.labelFiles}',
                            role: TextRole.detail,
                          ),
                          const Spacer(),
                          BaseLabel(
                            '+${stats.totalAdditions}',
                            role: TextRole.detail,
                            tone: Tone.gitAdded,
                          ),
                          const BaseGap(Proximity.hairline),
                          BaseLabel(
                            '-${stats.totalDeletions}',
                            role: TextRole.detail,
                            tone: Tone.gitDeleted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // File tree: `surfaces.tree` said once. The walk, the lazy
              // viewport, the indent rungs, each row's mark, the fold caret
              // and the row-action anchor are all the member's now - and with
              // them went the hand-built flatten, the per-depth padding
              // arithmetic and the shrunk PopupMenuButton.
              Expanded(
                child: SkinScope.render(context, (
                  Skin skin,
                  BuildContext inner,
                ) {
                  return skin.surfaces.tree(
                    inner,
                    _treeSpec(tree, displayedPath),
                  );
                }),
              ),
            ],
          );
        },
        loading: () => const BaseProgress.block(),
        // The same note as the empty case above, saying the other of the two
        // things the shape can say.
        error: (error, stack) => PanelNote(
          icon: PhosphorIconsRegular.warningCircle,
          message: AppLocalizations.of(context)!.errorLoadingData('files'),
          tone: Tone.danger,
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    IconRole icon,
    String count,
    Tone tone,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "How many files were added" - a working-tree meaning, not a colour
        // out of the git palette, and an inline-metadata mark at the one
        // scale the application gives that job.
        BaseIcon(icon, scale: ControlScale.compact, tone: tone),
        const BaseGap(Proximity.hairline),
        BaseLabel(count, role: TextRole.detail),
      ],
    );
  }

  /// The whole tree as the contract's data, from this panel's three facts:
  /// which files the commit changed, which directories the user folded shut,
  /// and which file's diff the neighbouring panel is showing.
  ///
  /// The displayed file is the tree's selection - marking it is what visually
  /// ties the list to the in-place diff - and it is also [TreeSpec.revealed]:
  /// when the displayed file changes, the member keeps its row in view, which
  /// this panel could never say while the scrollable was the member's own.
  /// `containerFocused` is false because this panel is not a keyboard
  /// collection - there is no roving highlight to wear a focus ring.
  TreeSpec _treeSpec(List<FileTreeNode> roots, String? displayedPath) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = <Object>{};
    final byPath = <String, FileTreeNode>{};

    TreeNodeSpec nodeSpec(FileTreeNode node) {
      byPath[node.fullPath] = node;
      final open = node.isDirectory && !_collapsed.contains(node.fullPath);
      if (open) expanded.add(node.fullPath);
      final change = node.fileChange;
      final isFile = !node.isDirectory && change != null;
      return TreeNodeSpec(
        id: node.fullPath,
        content: ContentPort(
          BaseLabel(node.name, role: TextRole.detail, maxLines: 1),
        ),
        children: [for (final child in node.children) nodeSpec(child)],
        leading: node.isDirectory
            ? (open ? IconRole.folderOpen : IconRole.folder)
            : FileIconUtils.getRoleForExtension(change?.extension ?? ''),
        // What happened to this file, said as a meaning rather than a colour.
        // In this panel the mark's tone is the ONLY per-row statement of that
        // fact - the +n/-n badge beside it does not say "deleted".
        leadingTone: isFile ? change.type.toneOf : null,
        // File change stats: the contract's paired badge. The counts are the
        // application's facts and everything else - the fill, the corner, the
        // inset, the gap between the halves - is the skin's answer to "two
        // facts in one mark" (#438, BadgeSpec.secondary).
        trailing: isFile
            ? ContentPort(
                DiffStatBadge(
                  additions: change.additions,
                  deletions: change.deletions,
                ),
              )
            : null,
        menu: isFile ? _fileMenu(node, change, l10n) : const <MenuEntry>[],
      );
    }

    final rootSpecs = [for (final node in roots) nodeSpec(node)];

    void toggleFold(Object id) {
      setState(() {
        final folder = id as String;
        if (!_collapsed.remove(folder)) _collapsed.add(folder);
      });
    }

    return TreeSpec(
      roots: rootSpecs,
      expanded: expanded,
      selected: {?displayedPath},
      containerFocused: false,
      revealed: displayedPath,
      onToggleExpanded: toggleFold,
      // A click on a directory folds it, exactly as it always has; a click on
      // a file highlights it so its diff renders in the panel beside this
      // list. The dialog stays reachable via double-click and the menu for a
      // focused read.
      onSelect: (id) {
        final node = byPath[id];
        if (node == null) return;
        if (node.isDirectory) {
          toggleFold(id);
          return;
        }
        ref
            .read(highlightedCommitFileProvider.notifier)
            .state = HighlightedCommitFile(
          commitHash: widget.commitHash,
          path: node.fullPath,
        );
      },
      onActivate: (id) {
        final node = byPath[id];
        if (node == null) return;
        if (node.isDirectory) {
          toggleFold(id);
          return;
        }
        showCommitFileDiffDialog(
          context,
          commitHash: widget.commitHash,
          filePath: node.fullPath,
        );
      },
    );
  }

  /// What can be done with one changed file, as data; the skin builds the
  /// row's anchor from it.
  List<MenuEntry> _fileMenu(
    FileTreeNode node,
    FileChange change,
    AppLocalizations l10n,
  ) {
    final isDeleted = change.type == FileChangeType.deleted;
    return <MenuEntry>[
      MenuAction(
        label: l10n.viewDiff,
        icon: IconRole.gitDiff,
        onPressed: () => showCommitFileDiffDialog(
          context,
          commitHash: widget.commitHash,
          filePath: node.fullPath,
        ),
      ),
      MenuAction(
        label: l10n.labelDownloadFile,
        icon: IconRole.download,
        onPressed: () =>
            _downloadFile(context, node.fullPath, isDeleted: isDeleted),
      ),
      MenuAction(
        label: l10n.openInEditor,
        icon: IconRole.textbox,
        onPressed: () =>
            _openInEditor(context, node.fullPath, isDeleted: isDeleted),
      ),
      MenuAction(
        label: l10n.labelDownloadAndOpenFolder,
        icon: IconRole.folderOpen,
        onPressed: () => _downloadAndOpenFolder(
          context,
          node.fullPath,
          isDeleted: isDeleted,
        ),
      ),
    ];
  }

  List<FileTreeNode> _buildFileTree(List<FileChange> files) {
    final rootNodes = <FileTreeNode>[];
    final nodeMap = <String, FileTreeNode>{};

    // Sort files by path
    final sortedFiles = List<FileChange>.from(files)
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in sortedFiles) {
      final parts = file.path.split('/');

      // Build directory structure
      String currentPath = '';
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isLast = i == parts.length - 1;
        final previousPath = currentPath;
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';

        if (!nodeMap.containsKey(currentPath)) {
          final node = FileTreeNode(
            name: part,
            fullPath: currentPath,
            isDirectory: !isLast,
            fileChange: isLast ? file : null,
            children: [],
          );

          nodeMap[currentPath] = node;

          // Add to parent or root
          if (previousPath.isEmpty) {
            rootNodes.add(node);
          } else {
            final parent = nodeMap[previousPath];
            if (parent != null) {
              (parent.children as List).add(node);
            }
          }
        }
      }
    }

    return rootNodes;
  }

  Future<void> _downloadFile(
    BuildContext context,
    String filePath, {
    bool isDeleted = false,
  }) async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) {
        Logger.warning('Download file: no repository open');
        if (context.mounted) {
          NotificationService.showWarning(context, 'No repository open');
        }
        return;
      }

      // Extract just the file name for the default save name
      final fileName = filePath.split('/').last;

      // Show save file dialog
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
      );

      if (outputPath == null) {
        // User cancelled
        return;
      }

      // Get file content at this commit (or parent if deleted)
      final commitRef = isDeleted
          ? '${widget.commitHash}^1'
          : widget.commitHash;
      Logger.info(
        'Downloading file from commit $commitRef: $filePath -> $outputPath',
      );
      final fileContent = await gitService.getFileContentAtCommit(
        commitRef,
        filePath,
      );

      // Write to file
      final file = File(outputPath);
      await file.writeAsBytes(fileContent);

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          AppLocalizations.of(context)!.messageFileSavedTo(outputPath),
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to download file: $filePath from commit ${widget.commitHash}',
        e,
      );
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to download file\nFile: $filePath\nCommit: ${widget.commitHash}\nError: $e',
        );
      }
    }
  }

  Future<void> _openInEditor(
    BuildContext context,
    String filePath, {
    bool isDeleted = false,
  }) async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) {
        Logger.warning('Open in editor: no repository open');
        if (context.mounted) {
          NotificationService.showWarning(context, 'No repository open');
        }
        return;
      }

      // Get preferred text editor from settings
      final tools = ref.read(toolsConfigProvider);
      final editorPath = tools.textEditor;

      if (editorPath == null || editorPath.isEmpty) {
        Logger.warning('Open in editor: no text editor configured');
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'No text editor configured. Please set a text editor in Settings.',
          );
        }
        return;
      }

      // Create temp directory for the file
      final tempDir = Directory.systemTemp.createTempSync('flutter_gitui_');
      final fileName = filePath.split('/').last;
      final tempFilePath = path.join(tempDir.path, fileName);

      // Get file content at this commit (or parent if deleted)
      final commitRef = isDeleted
          ? '${widget.commitHash}^1'
          : widget.commitHash;
      Logger.info('Opening file from commit $commitRef in editor: $filePath');
      final fileContent = await gitService.getFileContentAtCommit(
        commitRef,
        filePath,
      );

      // Write to temp file
      final file = File(tempFilePath);
      await file.writeAsBytes(fileContent);

      // Open in editor
      Logger.info('Launching editor: $editorPath with file: $tempFilePath');
      await EditorLauncherService.launch(
        editorPath: editorPath,
        targetPath: tempFilePath,
      );
    } catch (e) {
      Logger.error(
        'Failed to open file in editor: $filePath from commit ${widget.commitHash}',
        e,
      );
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to open file in editor\nEditor: ${ref.read(toolsConfigProvider).textEditor}\nFile: $filePath\nCommit: ${widget.commitHash}\nError: $e',
        );
      }
    }
  }

  Future<void> _downloadAndOpenFolder(
    BuildContext context,
    String filePath, {
    bool isDeleted = false,
  }) async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) {
        Logger.warning('Download and open folder: no repository open');
        if (context.mounted) {
          NotificationService.showWarning(context, 'No repository open');
        }
        return;
      }

      // Get repository working directory from provider
      final repoPath = ref.read(currentRepositoryPathProvider);
      if (repoPath == null) {
        Logger.warning(
          'Download and open folder: repository path not available',
        );
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Repository path not available',
          );
        }
        return;
      }

      // Get file content at this commit (or parent if deleted)
      final commitRef = isDeleted
          ? '${widget.commitHash}^1'
          : widget.commitHash;
      Logger.info(
        'Downloading file from commit $commitRef and opening folder: $filePath',
      );
      final fileContent = await gitService.getFileContentAtCommit(
        commitRef,
        filePath,
      );

      // Download into a temporary directory, never into the working tree.
      // Writing the historical version over the working copy silently destroyed
      // uncommitted edits -- and this action is a download, not a restore.
      final shortHash = widget.commitHash.length >= 8
          ? widget.commitHash.substring(0, 8)
          : widget.commitHash;
      final fullFilePath = path.join(
        Directory.systemTemp.path,
        'flutter-gitui',
        shortHash,
        path.basename(filePath),
      );

      final file = File(fullFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(fileContent);

      // Open the folder in file explorer
      Logger.info('Opening folder in file manager: ${file.parent.path}');
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', fullFilePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', fullFilePath]);
      } else if (Platform.isLinux) {
        // Open parent folder
        await Process.run('xdg-open', [file.parent.path]);
      }

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          AppLocalizations.of(context)!.messageFileDownloadedAndFolderOpened,
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to download file and open folder: $filePath from commit ${widget.commitHash}',
        e,
      );
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to download file and open folder\nFile: $filePath\nCommit: ${widget.commitHash}\nError: $e',
        );
      }
    }
  }
}
