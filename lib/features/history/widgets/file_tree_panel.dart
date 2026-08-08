import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/utils/file_icon_utils.dart';
import '../../../core/git/models/file_change.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/widgets/commit_file_diff_dialog.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/editor_launcher_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/double_tap_tracker.dart';
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
  // Clicking a file has to show its diff on the press. Registering onDoubleTap
  // on the row would make Flutter withhold that click for 300 ms, so the
  // double click is recognised from the interval between taps instead.
  final DoubleTapTracker _tapTracker = DoubleTapTracker();

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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.files,
                    size: AppTheme.iconXL,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  // The mark and the sentence under it are members of one
                  // statement: `grouped`.
                  const BaseGap(Proximity.grouped),
                  BaseLabel(
                    AppLocalizations.of(context)!.messageNoFilesChanged,
                    role: TextRole.body,
                    tone: Tone.muted,
                  ),
                ],
              ),
            );
          }

          final stats = FileChangeStats(files);
          final tree = _buildFileTree(files);
          final rows = _flattenVisible(tree);

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

              // File tree. Built lazily from the flattened rows so only the
              // visible ones are created.
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.paddingS),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _buildTreeRow(
                      context,
                      row.node,
                      row.depth,
                      displayedPath,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.warningCircle,
                size: AppTheme.iconXL,
                color: Theme.of(context).colorScheme.error,
              ),
              const BaseGap(Proximity.grouped),
              BaseLabel(
                AppLocalizations.of(context)!.errorLoadingData('files'),
                role: TextRole.body,
                tone: Tone.danger,
              ),
            ],
          ),
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

  /// The rows the list shows, in display order, each with its indent depth.
  ///
  /// The tree used to render as a Column nested per directory inside a plain
  /// ListView, which built every node - including those scrolled out of view -
  /// on every interaction. Flattening lets ListView.builder create only the
  /// rows actually on screen.
  List<({FileTreeNode node, int depth})> _flattenVisible(
    List<FileTreeNode> nodes,
  ) {
    final rows = <({FileTreeNode node, int depth})>[];

    void visit(List<FileTreeNode> level, int depth) {
      for (final node in level) {
        rows.add((node: node, depth: depth));
        if (node.isDirectory && node.isExpanded) {
          visit(node.children, depth + 1);
        }
      }
    }

    visit(nodes, 0);
    return rows;
  }

  Widget _buildTreeRow(
    BuildContext context,
    FileTreeNode node,
    int depth,
    String? displayedPath,
  ) {
    // The file whose diff the neighboring panel currently shows. Marking it
    // here is what visually ties the list to the in-place diff.
    final isDisplayedFile = !node.isDirectory && displayedPath == node.fullPath;

    return InkWell(
      // No onDoubleTap: registering one makes Flutter withhold every single
      // tap until the 300 ms double-tap window closes, which is what made
      // clicking a file feel slow. The tracker reports the double click.
      onTap: () {
        final isDoubleTap = _tapTracker.registerTap(node, DateTime.now());
        if (node.isDirectory) {
          setState(() {
            node.isExpanded = !node.isExpanded;
          });
          return;
        }
        if (isDoubleTap) {
          showCommitFileDiffDialog(
            context,
            commitHash: widget.commitHash,
            filePath: node.fullPath,
          );
          return;
        }
        // A click highlights the file so its diff renders in the panel
        // beside this list; the dialog stays reachable via double-click
        // and the menu for a focused read.
        ref
            .read(highlightedCommitFileProvider.notifier)
            .state = HighlightedCommitFile(
          commitHash: widget.commitHash,
          path: node.fullPath,
        );
      },
      child: Container(
        padding: EdgeInsets.only(
          left: depth * AppTheme.paddingM,
          top: 2,
          bottom: 2,
          right: AppTheme.paddingXS,
        ),
        decoration: isDisplayedFile
            ? BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              )
            : null,
        child: Row(
          children: [
            // Expand/collapse icon for directories
            if (node.isDirectory) ...[
              // The disclosure mark of a tree row: dense, and secondary to the
              // name beside it.
              BaseIcon(
                node.isExpanded ? IconRole.caretDown : IconRole.caretRight,
                scale: ControlScale.compact,
                tone: Tone.muted,
              ),
              const BaseGap(Proximity.hairline),
            ],

            // Folder/file icon
            Icon(
              node.isDirectory
                  ? (node.isExpanded
                        ? PhosphorIconsBold.folderOpen
                        : PhosphorIconsBold.folder)
                  : FileIconUtils.getIconForExtension(
                      node.fileChange?.extension ?? '',
                    ),
              size: AppTheme.iconS,
              color: node.isDirectory
                  ? Theme.of(context).colorScheme.primary
                  : (node.fileChange?.type.colorOf(context) ??
                        Theme.of(context).colorScheme.onSurface),
            ),
            const BaseGap(Proximity.related),

            // Name
            Expanded(
              child: BaseLabel(node.name, role: TextRole.detail, maxLines: 1),
            ),

            // File change stats
            if (!node.isDirectory && node.fileChange != null) ...[
              const BaseGap(Proximity.related),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (node.fileChange!.additions > 0) ...[
                      BaseLabel(
                        '+${node.fileChange!.additions}',
                        role: TextRole.micro,
                        tone: Tone.gitAdded,
                      ),
                    ],
                    if (node.fileChange!.additions > 0 &&
                        node.fileChange!.deletions > 0)
                      const SizedBox(width: 2),
                    if (node.fileChange!.deletions > 0) ...[
                      BaseLabel(
                        '-${node.fileChange!.deletions}',
                        role: TextRole.micro,
                        tone: Tone.gitDeleted,
                      ),
                    ],
                  ],
                ),
              ),
              // File actions menu
              const BaseGap(Proximity.hairline),
              PopupMenuButton<String>(
                icon: const Icon(
                  PhosphorIconsRegular.dotsThreeVertical,
                  size: AppTheme.iconXS,
                ),
                tooltip: AppLocalizations.of(context)!.tooltipFileActions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppTheme.paddingL,
                  minHeight: AppTheme.paddingL,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view_diff',
                    child: MenuItemContent(
                      icon: IconRole.gitDiff,
                      label: AppLocalizations.of(context)!.viewDiff,
                      scale: ControlScale.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: MenuItemContent(
                      icon: IconRole.download,
                      label: AppLocalizations.of(context)!.labelDownloadFile,
                      scale: ControlScale.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'open',
                    child: MenuItemContent(
                      icon: IconRole.textbox,
                      label: AppLocalizations.of(context)!.openInEditor,
                      scale: ControlScale.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'open_folder',
                    child: MenuItemContent(
                      icon: IconRole.folderOpen,
                      label: AppLocalizations.of(
                        context,
                      )!.labelDownloadAndOpenFolder,
                      scale: ControlScale.compact,
                    ),
                  ),
                ],
                onSelected: (value) async {
                  final isDeleted =
                      node.fileChange!.type == FileChangeType.deleted;
                  switch (value) {
                    case 'view_diff':
                      showCommitFileDiffDialog(
                        context,
                        commitHash: widget.commitHash,
                        filePath: node.fullPath,
                      );
                      break;
                    case 'download':
                      await _downloadFile(
                        context,
                        node.fullPath,
                        isDeleted: isDeleted,
                      );
                      break;
                    case 'open':
                      await _openInEditor(
                        context,
                        node.fullPath,
                        isDeleted: isDeleted,
                      );
                      break;
                    case 'open_folder':
                      await _downloadAndOpenFolder(
                        context,
                        node.fullPath,
                        isDeleted: isDeleted,
                      );
                      break;
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
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
