import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/models/tree_node.dart';
import '../../../shared/utils/file_icon_utils.dart';
import '../../../core/git/models/file_change.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/widgets/commit_file_diff_dialog.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';

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
  @override
  Widget build(BuildContext context) {
    final changedFilesAsync = ref.watch(
      commitChangedFilesProvider(widget.commitHash),
    );

    return BasePanel(
      title: Row(
        children: [
          Icon(
            PhosphorIconsRegular.tree,
            size: AppTheme.iconS,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingS),
          TitleSmallLabel(AppLocalizations.of(context)!.labelChangedFiles),
        ],
      ),
      padding: EdgeInsets.zero,
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
                  const SizedBox(height: AppTheme.paddingM),
                  BodyMediumLabel(
                    AppLocalizations.of(context)!.messageNoFilesChanged,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            );
          }

          final stats = FileChangeStats(files);
          final tree = _buildFileTree(files);

          return Column(
            children: [
              // Statistics bar
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatChip(
                          context,
                          PhosphorIconsRegular.plusCircle,
                          stats.addedFiles.toString(),
                          AppTheme.gitAdded,
                        ),
                        const SizedBox(width: AppTheme.paddingM),
                        _buildStatChip(
                          context,
                          PhosphorIconsRegular.pencilSimple,
                          stats.modifiedFiles.toString(),
                          AppTheme.gitModified,
                        ),
                        const SizedBox(width: AppTheme.paddingM),
                        _buildStatChip(
                          context,
                          PhosphorIconsRegular.minusCircle,
                          stats.deletedFiles.toString(),
                          AppTheme.gitDeleted,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.paddingS),
                    Row(
                      children: [
                        BodySmallLabel(
                          '${stats.totalFiles} ${stats.totalFiles == 1 ? AppLocalizations.of(context)!.labelFile : AppLocalizations.of(context)!.labelFiles}',
                        ),
                        const Spacer(),
                        BodySmallLabel(
                          '+${stats.totalAdditions}',
                          color: AppTheme.gitAdded,
                        ),
                        const SizedBox(width: AppTheme.paddingXS),
                        BodySmallLabel(
                          '-${stats.totalDeletions}',
                          color: AppTheme.gitDeleted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // File tree
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.paddingS),
                  children: tree
                      .map((node) => _buildTreeNode(context, node, 0))
                      .toList(),
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
              const SizedBox(height: AppTheme.paddingM),
              BodyMediumLabel(
                AppLocalizations.of(context)!.errorLoadingData('files'),
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String count,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppTheme.iconXS, color: color),
        const SizedBox(width: AppTheme.paddingXS),
        BodySmallLabel(
          count,
        ),
      ],
    );
  }

  Widget _buildTreeNode(BuildContext context, FileTreeNode node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: node.isDirectory
              ? () {
                  setState(() {
                    node.isExpanded = !node.isExpanded;
                  });
                }
              : () {
                  // Show diff for file
                  showCommitFileDiffDialog(
                    context,
                    commitHash: widget.commitHash,
                    filePath: node.fullPath,
                  );
                },
          child: Padding(
            padding: EdgeInsets.only(
              left: depth * AppTheme.paddingM,
              top: 2,
              bottom: 2,
              right: AppTheme.paddingXS,
            ),
            child: Row(
              children: [
                // Expand/collapse icon for directories
                if (node.isDirectory) ...[
                  Icon(
                    node.isExpanded
                        ? PhosphorIconsRegular.caretDown
                        : PhosphorIconsRegular.caretRight,
                    size: AppTheme.iconXS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingXS),
                ],

                // Folder/file icon
                Icon(
                  node.isDirectory
                      ? (node.isExpanded
                            ? PhosphorIconsBold.folderOpen
                            : PhosphorIconsBold.folder)
                      : FileIconUtils.getIconForExtension(node.fileChange?.extension ?? ''),
                  size: AppTheme.iconS,
                  color: node.isDirectory
                      ? Theme.of(context).colorScheme.primary
                      : (node.fileChange?.type.color ?? Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(width: AppTheme.paddingS),

                // Name
                Expanded(
                  child: BodySmallLabel(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // File change stats
                if (!node.isDirectory && node.fileChange != null) ...[
                  const SizedBox(width: AppTheme.paddingS),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.paddingXS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (node.fileChange!.additions > 0) ...[
                          LabelSmallLabel(
                            '+${node.fileChange!.additions}',
                            color: AppTheme.gitAdded,
                          ),
                        ],
                        if (node.fileChange!.additions > 0 &&
                            node.fileChange!.deletions > 0)
                          const SizedBox(width: 2),
                        if (node.fileChange!.deletions > 0) ...[
                          LabelSmallLabel(
                            '-${node.fileChange!.deletions}',
                            color: AppTheme.gitDeleted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // File actions menu
                  const SizedBox(width: AppTheme.paddingXS),
                  PopupMenuButton<String>(
                    icon: const Icon(PhosphorIconsRegular.dotsThreeVertical, size: AppTheme.iconXS),
                    tooltip: AppLocalizations.of(context)!.tooltipFileActions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppTheme.paddingL,
                      minHeight: AppTheme.paddingL,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'download',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.download,
                          label: AppLocalizations.of(context)!.labelDownloadFile,
                          iconSize: AppTheme.iconS,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'open',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.textbox,
                          label: AppLocalizations.of(context)!.openInEditor,
                          iconSize: AppTheme.iconS,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'open_folder',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.folderOpen,
                          label: AppLocalizations.of(context)!.labelDownloadAndOpenFolder,
                          iconSize: AppTheme.iconS,
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      final isDeleted =
                          node.fileChange!.type == FileChangeType.deleted;
                      switch (value) {
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
        ),

        // Children (if directory and expanded)
        if (node.isDirectory && node.isExpanded)
          ...node.children.map(
            (child) => _buildTreeNode(context, child, depth + 1),
          ),
      ],
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
          NotificationService.showWarning(
            context,
            'No repository open',
          );
        }
        return;
      }

      // Extract just the file name for the default save name
      final fileName = filePath.split('/').last;

      // Show save file dialog
      final outputPath = await FilePicker.platform.saveFile(
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
      Logger.info('Downloading file from commit $commitRef: $filePath -> $outputPath');
      final fileContent = await gitService.getFileContentAtCommit(
        commitRef,
        filePath,
      );

      // Write to file
      final file = File(outputPath);
      await file.writeAsBytes(fileContent);

      if (context.mounted) {
        NotificationService.showSuccess(context, AppLocalizations.of(context)!.messageFileSavedTo(outputPath));
      }
    } catch (e) {
      Logger.error('Failed to download file: $filePath from commit ${widget.commitHash}', e);
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
          NotificationService.showWarning(
            context,
            'No repository open',
          );
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
      final result = await Process.run(editorPath, [tempFilePath]);

      if (result.exitCode != 0) {
        Logger.error('Editor process exited with code ${result.exitCode}: ${result.stderr}');
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to open editor\nEditor: $editorPath\nFile: $filePath\nExit code: ${result.exitCode}\nError: ${result.stderr}',
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to open file in editor: $filePath from commit ${widget.commitHash}', e);
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
          NotificationService.showWarning(
            context,
            'No repository open',
          );
        }
        return;
      }

      // Get repository working directory from provider
      final repoPath = ref.read(currentRepositoryPathProvider);
      if (repoPath == null) {
        Logger.warning('Download and open folder: repository path not available');
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
      Logger.info('Downloading file from commit $commitRef and opening folder: $filePath');
      final fileContent = await gitService.getFileContentAtCommit(
        commitRef,
        filePath,
      );

      // Full path to the file in repository
      final fullFilePath = path.join(repoPath, filePath);

      // Ensure parent directories exist
      final file = File(fullFilePath);
      await file.parent.create(recursive: true);

      // Silently overwrite the file
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
        NotificationService.showSuccess(context, AppLocalizations.of(context)!.messageFileDownloadedAndFolderOpened);
      }
    } catch (e) {
      Logger.error('Failed to download file and open folder: $filePath from commit ${widget.commitHash}', e);
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to download file and open folder\nFile: $filePath\nCommit: ${widget.commitHash}\nError: $e',
        );
      }
    }
  }
}

