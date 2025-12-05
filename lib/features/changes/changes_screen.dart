import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_dialog.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/git/models/file_status.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/services/services.dart';
import '../../core/utils/windows_filename_validator.dart';
import '../../core/utils/result_extensions.dart';
import 'widgets/commit_dialog.dart';
import 'widgets/changes_clean_state.dart';
import 'widgets/changes_error_state.dart';
import 'widgets/git_status_tree_view.dart';

/// Changes screen - Working directory, staging, and commits
class ChangesScreen extends ConsumerStatefulWidget {
  const ChangesScreen({super.key});

  @override
  ConsumerState<ChangesScreen> createState() => _ChangesScreenState();
}

class _ChangesScreenState extends ConsumerState<ChangesScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final statusAsync = ref.watch(repositoryStatusProvider);
    final stagedFiles = ref.watch(stagedFilesProvider);
    final unstagedFiles = ref.watch(unstagedFilesProvider);

    // No repository open
    if (repositoryPath == null) {
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.folderOpen,
        title: 'No Repository Open',
        message: 'Open a repository to see changes',
        action: BaseButton(
          label: AppLocalizations.of(context)!.openRepository,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.folderOpen,
          onPressed: () => _openRepository(context, ref),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppDestination.changes.label(context)),
        actions: [
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowsClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: () {
              ref.read(gitActionsProvider).refreshStatus();
            },
          ),
        ],
      ),
      body: statusAsync.when(
        data: (allStatuses) {
          if (allStatuses.isEmpty) {
            return const ChangesCleanState();
          }

          return Column(
            children: [
              Expanded(
                child: _buildFileList(
                  context,
                  ref,
                  stagedFiles,
                  unstagedFiles,
                ),
              ),
              // Fixed commit button bar
              if (stagedFiles.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  child: SafeArea(
                    child: unstagedFiles.isEmpty
                        ? // Only staged files - show single "Commit" button
                        BaseButton(
                            label: AppLocalizations.of(context)!.commit,
                            leadingIcon: PhosphorIconsRegular.check,
                            onPressed: () => _commitStagedOnly(context, ref),
                            variant: ButtonVariant.primary,
                            size: ButtonSize.medium,
                            fullWidth: true,
                          )
                        : // Both staged and unstaged files - show two buttons
                        Row(
                            children: [
                              Expanded(
                                child: BaseButton(
                                  label: AppLocalizations.of(context)!.commit,
                                  leadingIcon: PhosphorIconsRegular.check,
                                  onPressed: () => _commitStagedOnly(context, ref),
                                  variant: ButtonVariant.secondary,
                                  size: ButtonSize.medium,
                                ),
                              ),
                              const SizedBox(width: AppTheme.paddingM),
                              Expanded(
                                child: BaseButton(
                                  label: AppLocalizations.of(context)!.stageAllAndCommit,
                                  leadingIcon: PhosphorIconsRegular.checkCircle,
                                  onPressed: () => _handleCommit(context, ref, unstagedFiles, stagedFiles),
                                  variant: ButtonVariant.primary,
                                  size: ButtonSize.medium,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => ChangesErrorState(error: error),
      ),
    );
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    List<FileStatus> stagedFiles,
    List<FileStatus> unstagedFiles,
  ) {
    return Column(
      children: [
        // Quick actions bar
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              BaseButton(
                label: AppLocalizations.of(context)!.stageAll,
                leadingIcon: PhosphorIconsRegular.plus,
                onPressed: unstagedFiles.isNotEmpty
                    ? () async => await _confirmStageAll(context, ref)
                    : null,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
              ),
              const SizedBox(width: AppTheme.paddingS),
              BaseButton(
                label: AppLocalizations.of(context)!.unstageAll,
                leadingIcon: PhosphorIconsRegular.minus,
                onPressed: stagedFiles.isNotEmpty
                    ? () async => await _confirmUnstageAll(context, ref)
                    : null,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
              ),
              const Spacer(),
              BaseButton(
                label: AppLocalizations.of(context)!.tooltipDiscardAllChanges,
                leadingIcon: PhosphorIconsRegular.trash,
                onPressed: unstagedFiles.isNotEmpty
                    ? () => _confirmDiscardAll(context, ref)
                    : null,
                variant: ButtonVariant.dangerSecondary,
                size: ButtonSize.small,
              ),
            ],
          ),
        ),

        // Split view: tree on left, diff on right
        Expanded(
          child: GitStatusTreeView(
            stagedFiles: stagedFiles,
            unstagedFiles: unstagedFiles,
            onToggleStage: (file, currentlyStaged) async {
              try {
                if (currentlyStaged) {
                  await ref.read(gitActionsProvider).unstageFile(file.path);
                } else {
                  await ref.read(gitActionsProvider).stageFile(file.path);
                }
              } catch (e) {
                if (!mounted) return;
                if (!context.mounted) return;
                await _handleStagingError(context, file.path, e.toString());
              }
            },
            onDiscardFile: (file) => _confirmDiscardFile(context, ref, file),
            onDeleteFile: (file) => _confirmDeleteFile(context, ref, file),
          ),
        ),
      ],
    );
  }


  Future<void> _openRepository(BuildContext context, WidgetRef ref) async {
    // Check if running on web
    if (kIsWeb) {
      if (context.mounted) {
        await BaseDialog.show(
          context: context,
          dialog: BaseDialog(
            title: AppLocalizations.of(context)!.dialogTitleWebBrowserLimitation,
            icon: PhosphorIconsRegular.globe,
            content: BodyMediumLabel(
              AppLocalizations.of(context)!.dialogContentWebBrowserLimitationChanges,
            ),
            actions: [
              BaseButton(
                label: AppLocalizations.of(context)!.ok,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Use file picker to select directory
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Git Repository',
    );

    if (result != null) {
      final success = await ref.read(gitActionsProvider).openRepository(result);

      if (!success && mounted) {
        context.showErrorIfMounted('Not a valid Git repository');
      }
    }
  }

  Future<void> _handleCommit(
    BuildContext context,
    WidgetRef ref,
    List<FileStatus> unstagedFiles,
    List<FileStatus> stagedFiles,
  ) async {
    // If there are unstaged files, warn the user they will be staged
    if (unstagedFiles.isNotEmpty) {
      final confirmed = await BaseDialog.show<bool>(
        context: context,
        dialog: BaseDialog(
          title: AppLocalizations.of(context)!.stageAllAndCommit,
          icon: PhosphorIconsRegular.warningCircle,
          variant: DialogVariant.confirmation,
          content: BodyMediumLabel(
            AppLocalizations.of(context)!.dialogContentStageAllAndCommit(unstagedFiles.length, unstagedFiles.length == 1 ? '' : 's'),
          ),
          actions: [
            BaseButton(
              label: AppLocalizations.of(context)!.cancel,
              variant: ButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            BaseButton(
              label: AppLocalizations.of(context)!.stageAllAndCommit,
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Stage all files
      if (context.mounted) {
        await ref.read(gitActionsProvider).stageAll();
      }
    }

    // Show commit dialog
    if (context.mounted) {
      await _showCommitDialog(context, ref);
    }
  }

  Future<void> _showCommitDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => const CommitDialog(),
    );
  }

  /// Commits only the currently staged files without staging unstaged files.
  /// Goes directly to commit dialog without confirmation.
  Future<void> _commitStagedOnly(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      await _showCommitDialog(context, ref);
    }
  }

  Future<void> _confirmDiscardFile(
    BuildContext context,
    WidgetRef ref,
    FileStatus file,
  ) async {
    final confirmed = await BaseDialog.show<bool>(
      context: context,
      dialog: BaseDialog(
        icon: PhosphorIconsRegular.arrowCounterClockwise,
        title: AppLocalizations.of(context)!.discardChangesQuestion,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(
          AppLocalizations.of(context)!.dialogContentDiscardChangesFile(file.path),
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.discardAll,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(gitActionsProvider).discardFile(file.path);
    }
  }

  Future<void> _confirmDeleteFile(
    BuildContext context,
    WidgetRef ref,
    FileStatus file,
  ) async {
    final confirmed = await BaseDialog.show<bool>(
      context: context,
      dialog: BaseDialog(
        icon: PhosphorIconsRegular.trash,
        title: AppLocalizations.of(context)!.dialogTitleDeleteFile,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(
          AppLocalizations.of(context)!.dialogContentDeleteFile(file.path),
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.delete,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(gitActionsProvider).deleteUntrackedFile(file.path);
    }
  }

  Future<void> _handleStagingError(BuildContext context, String filePath, String errorMessage) async {
    // Check if this is a Windows reserved filename error
    if (WindowsFilenameValidator.isReservedNameError(errorMessage)) {
      final problematicFile = WindowsFilenameValidator.extractFilenameFromError(errorMessage) ?? filePath;

      await showDialog(
        context: context,
        builder: (dialogContext) => BaseDialog(
          icon: PhosphorIconsRegular.warningCircle,
          title: AppLocalizations.of(context)!.dialogTitleWindowsReservedFilename,
          content: SingleChildScrollView(
            child: Text(WindowsFilenameValidator.getErrorMessage(problematicFile, dialogContext)),
          ),
          variant: DialogVariant.destructive,
          actions: [
            BaseButton(
              label: AppLocalizations.of(context)!.ok,
              variant: ButtonVariant.tertiary,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
    } else {
      // Show regular error message
      NotificationService.showError(context, 'Failed to stage file: $errorMessage');
    }
  }

  Future<void> _confirmStageAll(BuildContext context, WidgetRef ref) async {
    final unstagedFiles = ref.read(unstagedFilesProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.plus,
        title: AppLocalizations.of(context)!.stageAllChangesQuestion,
        variant: DialogVariant.confirmation,
        content: BodyMediumLabel(AppLocalizations.of(context)!.dialogContentStageAllFiles(unstagedFiles.length, unstagedFiles.length == 1 ? '' : 's')),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.stageAll,
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(gitActionsProvider).stageAll();
      } catch (e) {
        if (!context.mounted) return;
        await _handleStagingError(context, 'multiple files', e.toString());
      }
    }
  }

  Future<void> _confirmUnstageAll(BuildContext context, WidgetRef ref) async {
    final stagedFiles = ref.read(stagedFilesProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.minus,
        title: AppLocalizations.of(context)!.unstageAllChangesQuestion,
        variant: DialogVariant.confirmation,
        content: BodyMediumLabel(
            'Unstage all ${stagedFiles.length} staged file${stagedFiles.length == 1 ? '' : 's'}?'),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.unstageAll,
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(gitActionsProvider).unstageAll();
    }
  }

  Future<void> _confirmDiscardAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.trash,
        title: AppLocalizations.of(context)!.discardAllChangesQuestion,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(AppLocalizations.of(context)!.discardAllChangesConfirm),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.discardAll,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(gitActionsProvider).discardAll();
    }
  }

}
