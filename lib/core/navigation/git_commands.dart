import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../generated/app_localizations.dart';

import 'navigation_item.dart';
import '../../shared/dialogs/bisect_dialog.dart';
import '../../shared/dialogs/clone_repository_dialog.dart';
import '../../shared/dialogs/create_tag_dialog.dart';
import '../../shared/dialogs/diff_tools_config_dialog.dart';
import '../../shared/dialogs/initialize_repository_dialog.dart';
import '../../shared/dialogs/merge_branch_dialog.dart';
import '../../shared/dialogs/rebase_dialog.dart';
import '../../shared/dialogs/reflog_dialog.dart';
import '../git/git_providers.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_label.dart';
import '../services/notification_service.dart';

/// Category of Git command
enum CommandCategory {
  repository,
  changes,
  history,
  branches,
  remotes,
  stashes,
  tags,
  submodules,
  advanced,
  settings;

  /// Get localized name for this command category
  String getLocalizedName(AppLocalizations l10n) {
    switch (this) {
      case CommandCategory.repository:
        return l10n.commandCategoryRepository;
      case CommandCategory.changes:
        return l10n.commandCategoryChanges;
      case CommandCategory.history:
        return l10n.commandCategoryHistory;
      case CommandCategory.branches:
        return l10n.commandCategoryBranches;
      case CommandCategory.remotes:
        return l10n.commandCategoryRemotes;
      case CommandCategory.stashes:
        return l10n.commandCategoryStashes;
      case CommandCategory.tags:
        return l10n.commandCategoryTags;
      case CommandCategory.submodules:
        return l10n.commandCategorySubmodules;
      case CommandCategory.advanced:
        return l10n.commandCategoryAdvanced;
      case CommandCategory.settings:
        return l10n.commandCategorySettings;
    }
  }

  @Deprecated('Use getLocalizedName(AppLocalizations) instead')
  String get name {
    switch (this) {
      case CommandCategory.repository:
        return 'Repository';
      case CommandCategory.changes:
        return 'Changes & Commits';
      case CommandCategory.history:
        return 'History & Diffs';
      case CommandCategory.branches:
        return 'Branches';
      case CommandCategory.remotes:
        return 'Remotes';
      case CommandCategory.stashes:
        return 'Stashes';
      case CommandCategory.tags:
        return 'Tags';
      case CommandCategory.submodules:
        return 'Submodules';
      case CommandCategory.advanced:
        return 'Advanced';
      case CommandCategory.settings:
        return 'Settings';
    }
  }
}

/// A Git command that can be executed from the command palette
class GitCommand {
  /// Key for localized title (e.g., 'commandCloneRepository')
  final String titleKey;

  /// Key for localized description (e.g., 'commandCloneRepositoryDesc')
  final String descriptionKey;

  final IconData icon;
  final CommandCategory category;
  final String? shortcut;
  final void Function(BuildContext context, WidgetRef ref) onExecute;

  const GitCommand({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.category,
    required this.onExecute,
    this.shortcut,
  });

  /// Get localized title
  String getTitle(AppLocalizations l10n) {
    switch (titleKey) {
      case 'commandCloneRepository':
        return l10n.commandCloneRepository;
      case 'commandOpenRepository':
        return l10n.commandOpenRepository;
      case 'commandInitializeRepository':
        return l10n.commandInitializeRepository;
      case 'commandCommitChanges':
        return l10n.commandCommitChanges;
      case 'commandAmendLastCommit':
        return l10n.commandAmendLastCommit;
      case 'commandStageAllFiles':
        return l10n.commandStageAllFiles;
      case 'commandUnstageAllFiles':
        return l10n.commandUnstageAllFiles;
      case 'commandDiscardAllChanges':
        return l10n.commandDiscardAllChanges;
      case 'commandViewCommitHistory':
        return l10n.commandViewCommitHistory;
      case 'commandViewFileHistory':
        return l10n.commandViewFileHistory;
      case 'commandCompareBranches':
        return l10n.commandCompareBranches;
      case 'commandCreateBranch':
        return l10n.commandCreateBranch;
      case 'commandCheckoutBranch':
        return l10n.commandCheckoutBranch;
      case 'commandRenameBranch':
        return l10n.commandRenameBranch;
      case 'commandDeleteBranch':
        return l10n.commandDeleteBranch;
      case 'commandMergeBranch':
        return l10n.commandMergeBranch;
      case 'commandRebaseBranch':
        return l10n.commandRebaseBranch;
      case 'commandFetchFromRemote':
        return l10n.commandFetchFromRemote;
      case 'commandPullChanges':
        return l10n.commandPullChanges;
      case 'commandPullWithRebase':
        return l10n.commandPullWithRebase;
      case 'commandPushChanges':
        return l10n.commandPushChanges;
      case 'commandManageRemotes':
        return l10n.commandManageRemotes;
      case 'commandStashChanges':
        return l10n.commandStashChanges;
      case 'commandPopStash':
        return l10n.commandPopStash;
      case 'commandApplyStash':
        return l10n.commandApplyStash;
      case 'commandViewAllStashes':
        return l10n.commandViewAllStashes;
      case 'commandCreateTag':
        return l10n.commandCreateTag;
      case 'commandDeleteTag':
        return l10n.commandDeleteTag;
      case 'commandPushTag':
        return l10n.commandPushTag;
      case 'commandStartBisect':
        return l10n.commandStartBisect;
      case 'commandViewReflog':
        return l10n.commandViewReflog;
      case 'commandCherryPickCommit':
        return l10n.commandCherryPickCommit;
      case 'commandRevertCommit':
        return l10n.commandRevertCommit;
      case 'commandResetToCommit':
        return l10n.commandResetToCommit;
      case 'commandCleanWorkingDirectory':
        return l10n.commandCleanWorkingDirectory;
      case 'commandOpenSettings':
        return l10n.commandOpenSettings;
      case 'commandConfigureDiffTools':
        return l10n.commandConfigureDiffTools;
      default:
        return titleKey;
    }
  }

  /// Get localized description
  String getDescription(AppLocalizations l10n) {
    switch (descriptionKey) {
      case 'commandCloneRepositoryDesc':
        return l10n.commandCloneRepositoryDesc;
      case 'commandOpenRepositoryDesc':
        return l10n.commandOpenRepositoryDesc;
      case 'commandInitializeRepositoryDesc':
        return l10n.commandInitializeRepositoryDesc;
      case 'commandCommitChangesDesc':
        return l10n.commandCommitChangesDesc;
      case 'commandAmendLastCommitDesc':
        return l10n.commandAmendLastCommitDesc;
      case 'commandStageAllFilesDesc':
        return l10n.commandStageAllFilesDesc;
      case 'commandUnstageAllFilesDesc':
        return l10n.commandUnstageAllFilesDesc;
      case 'commandDiscardAllChangesDesc':
        return l10n.commandDiscardAllChangesDesc;
      case 'commandViewCommitHistoryDesc':
        return l10n.commandViewCommitHistoryDesc;
      case 'commandViewFileHistoryDesc':
        return l10n.commandViewFileHistoryDesc;
      case 'commandCompareBranchesDesc':
        return l10n.commandCompareBranchesDesc;
      case 'commandCreateBranchDesc':
        return l10n.commandCreateBranchDesc;
      case 'commandCheckoutBranchDesc':
        return l10n.commandCheckoutBranchDesc;
      case 'commandRenameBranchDesc':
        return l10n.commandRenameBranchDesc;
      case 'commandDeleteBranchDesc':
        return l10n.commandDeleteBranchDesc;
      case 'commandMergeBranchDesc':
        return l10n.commandMergeBranchDesc;
      case 'commandRebaseBranchDesc':
        return l10n.commandRebaseBranchDesc;
      case 'commandFetchFromRemoteDesc':
        return l10n.commandFetchFromRemoteDesc;
      case 'commandPullChangesDesc':
        return l10n.commandPullChangesDesc;
      case 'commandPullWithRebaseDesc':
        return l10n.commandPullWithRebaseDesc;
      case 'commandPushChangesDesc':
        return l10n.commandPushChangesDesc;
      case 'commandManageRemotesDesc':
        return l10n.commandManageRemotesDesc;
      case 'commandStashChangesDesc':
        return l10n.commandStashChangesDesc;
      case 'commandPopStashDesc':
        return l10n.commandPopStashDesc;
      case 'commandApplyStashDesc':
        return l10n.commandApplyStashDesc;
      case 'commandViewAllStashesDesc':
        return l10n.commandViewAllStashesDesc;
      case 'commandCreateTagDesc':
        return l10n.commandCreateTagDesc;
      case 'commandDeleteTagDesc':
        return l10n.commandDeleteTagDesc;
      case 'commandPushTagDesc':
        return l10n.commandPushTagDesc;
      case 'commandStartBisectDesc':
        return l10n.commandStartBisectDesc;
      case 'commandViewReflogDesc':
        return l10n.commandViewReflogDesc;
      case 'commandCherryPickCommitDesc':
        return l10n.commandCherryPickCommitDesc;
      case 'commandRevertCommitDesc':
        return l10n.commandRevertCommitDesc;
      case 'commandResetToCommitDesc':
        return l10n.commandResetToCommitDesc;
      case 'commandCleanWorkingDirectoryDesc':
        return l10n.commandCleanWorkingDirectoryDesc;
      case 'commandOpenSettingsDesc':
        return l10n.commandOpenSettingsDesc;
      case 'commandConfigureDiffToolsDesc':
        return l10n.commandConfigureDiffToolsDesc;
      default:
        return descriptionKey;
    }
  }

  @Deprecated('Use getTitle(AppLocalizations) instead')
  String get title => titleKey;

  @Deprecated('Use getDescription(AppLocalizations) instead')
  String get description => descriptionKey;
}

/// All available Git commands
class GitCommands {
  GitCommands._();

  /// All commands (300+ to be implemented)
  static final List<GitCommand> all = [
    // ========================================
    // Repository
    // ========================================
    GitCommand(
      titleKey: 'commandCloneRepository',
      descriptionKey: 'commandCloneRepositoryDesc',
      icon: PhosphorIconsRegular.downloadSimple,
      category: CommandCategory.repository,
      onExecute: (context, ref) {
        showCloneRepositoryDialog(context);
      },
    ),
    GitCommand(
      titleKey: 'commandOpenRepository',
      descriptionKey: 'commandOpenRepositoryDesc',
      icon: PhosphorIconsRegular.folderOpen,
      category: CommandCategory.repository,
      shortcut: 'Ctrl+O',
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.folderSelectionNotAvailableWeb)),
          );
          return;
        }

        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: l10n.selectGitRepository,
        );

        if (result != null && context.mounted) {
          final success = await ref
              .read(gitActionsProvider)
              .openRepository(result);

          if (context.mounted && !success) {
            final l10n = AppLocalizations.of(context);
            if (l10n == null) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.notValidGitRepository(result))),
            );
          }
        }
      },
    ),
    GitCommand(
      titleKey: 'commandInitializeRepository',
      descriptionKey: 'commandInitializeRepositoryDesc',
      icon: PhosphorIconsRegular.plus,
      category: CommandCategory.repository,
      onExecute: (context, ref) {
        showInitializeRepositoryDialog(context);
      },
    ),

    // ========================================
    // Changes & Commits
    // ========================================
    GitCommand(
      titleKey: 'commandCommitChanges',
      descriptionKey: 'commandCommitChangesDesc',
      icon: PhosphorIconsRegular.check,
      category: CommandCategory.changes,
      shortcut: 'C',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.changes;
      },
    ),
    GitCommand(
      titleKey: 'commandAmendLastCommit',
      descriptionKey: 'commandAmendLastCommitDesc',
      icon: PhosphorIconsRegular.pencilSimple,
      category: CommandCategory.changes,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        final confirmed = await BaseDialog.show<bool>(
          context: context,
          dialog: BaseDialog(
            title: l10n.amendLastCommitDialog,
            icon: PhosphorIconsRegular.pencilSimple,
            variant: DialogVariant.confirmation,
            content: BodyMediumLabel(l10n.amendLastCommitConfirm),
            actions: [
              BaseButton(
                label: l10n.cancel,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              BaseButton(
                label: l10n.amend,
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await ref.read(gitActionsProvider).amendCommit(noEdit: true);
          } catch (e) {
            if (context.mounted) {
              final l10n = AppLocalizations.of(context);
              if (l10n != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.failedToAmendCommit(e.toString())),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          }
        }
      },
    ),
    GitCommand(
      titleKey: 'commandStageAllFiles',
      descriptionKey: 'commandStageAllFilesDesc',
      icon: PhosphorIconsRegular.checkSquare,
      category: CommandCategory.changes,
      shortcut: 'Ctrl+A',
      onExecute: (context, ref) async {
        try {
          await ref.read(gitActionsProvider).stageAll();
        } catch (e) {
          if (!context.mounted) return;
          NotificationService.showError(
            context,
            'Failed to stage all files: $e',
          );
        }
      },
    ),
    GitCommand(
      titleKey: 'commandUnstageAllFiles',
      descriptionKey: 'commandUnstageAllFilesDesc',
      icon: PhosphorIconsRegular.square,
      category: CommandCategory.changes,
      onExecute: (context, ref) async {
        try {
          await ref.read(gitActionsProvider).unstageAll();
        } catch (e) {
          if (!context.mounted) return;
          NotificationService.showError(
            context,
            'Failed to unstage all files: $e',
          );
        }
      },
    ),
    GitCommand(
      titleKey: 'commandDiscardAllChanges',
      descriptionKey: 'commandDiscardAllChangesDesc',
      icon: PhosphorIconsRegular.trash,
      category: CommandCategory.changes,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        final confirmed = await BaseDialog.show<bool>(
          context: context,
          dialog: BaseDialog(
            title: l10n.discardAllChangesDialog,
            icon: PhosphorIconsRegular.trash,
            variant: DialogVariant.destructive,
            content: BodyMediumLabel(l10n.discardAllChangesConfirm),
            actions: [
              BaseButton(
                label: l10n.cancel,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              BaseButton(
                label: l10n.discardAll,
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await ref.read(gitActionsProvider).discardAll();
          } catch (e) {
            if (!context.mounted) return;
            NotificationService.showError(
              context,
              'Failed to discard all changes: $e',
            );
          }
        }
      },
    ),

    // ========================================
    // History & Diffs
    // ========================================
    GitCommand(
      titleKey: 'commandViewCommitHistory',
      descriptionKey: 'commandViewCommitHistoryDesc',
      icon: PhosphorIconsRegular.clockCounterClockwise,
      category: CommandCategory.history,
      shortcut: 'H',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.history;
      },
    ),
    GitCommand(
      titleKey: 'commandViewFileHistory',
      descriptionKey: 'commandViewFileHistoryDesc',
      icon: PhosphorIconsRegular.fileText,
      category: CommandCategory.history,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.history;
      },
    ),
    GitCommand(
      titleKey: 'commandCompareBranches',
      descriptionKey: 'commandCompareBranchesDesc',
      icon: PhosphorIconsRegular.gitDiff,
      category: CommandCategory.history,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.branches;
      },
    ),

    // ========================================
    // Branches
    // ========================================
    GitCommand(
      titleKey: 'commandCreateBranch',
      descriptionKey: 'commandCreateBranchDesc',
      icon: PhosphorIconsRegular.gitBranch,
      category: CommandCategory.branches,
      shortcut: 'Ctrl+B',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.branches;
      },
    ),
    GitCommand(
      titleKey: 'commandCheckoutBranch',
      descriptionKey: 'commandCheckoutBranchDesc',
      icon: PhosphorIconsRegular.arrowsLeftRight,
      category: CommandCategory.branches,
      shortcut: 'B',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.branches;
      },
    ),
    GitCommand(
      titleKey: 'commandRenameBranch',
      descriptionKey: 'commandRenameBranchDesc',
      icon: PhosphorIconsRegular.textT,
      category: CommandCategory.branches,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.branches;
      },
    ),
    GitCommand(
      titleKey: 'commandDeleteBranch',
      descriptionKey: 'commandDeleteBranchDesc',
      icon: PhosphorIconsRegular.trash,
      category: CommandCategory.branches,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.branches;
      },
    ),
    GitCommand(
      titleKey: 'commandMergeBranch',
      descriptionKey: 'commandMergeBranchDesc',
      icon: PhosphorIconsRegular.gitMerge,
      category: CommandCategory.branches,
      shortcut: 'M',
      onExecute: (context, ref) async {
        final hasConflicts = await showMergeBranchDialog(context);

        // If merge resulted in conflicts, navigate to conflict resolution
        if (hasConflicts == true && context.mounted) {
          Navigator.of(context).pushNamed('/conflicts');
        }
      },
    ),
    GitCommand(
      titleKey: 'commandRebaseBranch',
      descriptionKey: 'commandRebaseBranchDesc',
      icon: PhosphorIconsRegular.arrowsCounterClockwise,
      category: CommandCategory.branches,
      shortcut: 'R',
      onExecute: (context, ref) async {
        await showRebaseDialog(context);
      },
    ),

    // ========================================
    // Remotes
    // ========================================
    GitCommand(
      titleKey: 'commandFetchFromRemote',
      descriptionKey: 'commandFetchFromRemoteDesc',
      icon: PhosphorIconsRegular.downloadSimple,
      category: CommandCategory.remotes,
      shortcut: 'F',
      onExecute: (context, ref) {
        ref.read(gitActionsProvider).fetchRemote();
      },
    ),
    GitCommand(
      titleKey: 'commandPullChanges',
      descriptionKey: 'commandPullChangesDesc',
      icon: PhosphorIconsRegular.arrowDown,
      category: CommandCategory.remotes,
      shortcut: 'Ctrl+P',
      onExecute: (context, ref) {
        ref.read(gitActionsProvider).pullRemote();
      },
    ),
    GitCommand(
      titleKey: 'commandPullWithRebase',
      descriptionKey: 'commandPullWithRebaseDesc',
      icon: PhosphorIconsRegular.arrowDown,
      category: CommandCategory.remotes,
      onExecute: (context, ref) {
        ref.read(gitActionsProvider).pullRemote(rebase: true);
      },
    ),
    GitCommand(
      titleKey: 'commandPushChanges',
      descriptionKey: 'commandPushChangesDesc',
      icon: PhosphorIconsRegular.arrowUp,
      category: CommandCategory.remotes,
      shortcut: 'Ctrl+Shift+P',
      onExecute: (context, ref) {
        ref.read(gitActionsProvider).pushRemote();
      },
    ),

    // ========================================
    // Stashes
    // ========================================
    GitCommand(
      titleKey: 'commandStashChanges',
      descriptionKey: 'commandStashChangesDesc',
      icon: PhosphorIconsRegular.package,
      category: CommandCategory.stashes,
      shortcut: 'S',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.stashes;
      },
    ),
    GitCommand(
      titleKey: 'commandPopStash',
      descriptionKey: 'commandPopStashDesc',
      icon: PhosphorIconsRegular.arrowUUpLeft,
      category: CommandCategory.stashes,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.stashes;
      },
    ),
    GitCommand(
      titleKey: 'commandApplyStash',
      descriptionKey: 'commandApplyStashDesc',
      icon: PhosphorIconsRegular.arrowDown,
      category: CommandCategory.stashes,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.stashes;
      },
    ),
    GitCommand(
      titleKey: 'commandViewAllStashes',
      descriptionKey: 'commandViewAllStashesDesc',
      icon: PhosphorIconsRegular.listBullets,
      category: CommandCategory.stashes,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.stashes;
      },
    ),

    // ========================================
    // Tags
    // ========================================
    GitCommand(
      titleKey: 'commandCreateTag',
      descriptionKey: 'commandCreateTagDesc',
      icon: PhosphorIconsRegular.tag,
      category: CommandCategory.tags,
      shortcut: 'T',
      onExecute: (context, ref) async {
        await showCreateTagDialog(context);
      },
    ),
    GitCommand(
      titleKey: 'commandDeleteTag',
      descriptionKey: 'commandDeleteTagDesc',
      icon: PhosphorIconsRegular.trash,
      category: CommandCategory.tags,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.tags;
      },
    ),
    GitCommand(
      titleKey: 'commandPushTag',
      descriptionKey: 'commandPushTagDesc',
      icon: PhosphorIconsRegular.arrowUp,
      category: CommandCategory.tags,
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.tags;
      },
    ),

    // ========================================
    // Advanced
    // ========================================
    GitCommand(
      titleKey: 'commandStartBisect',
      descriptionKey: 'commandStartBisectDesc',
      icon: PhosphorIconsRegular.magnifyingGlass,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        await showBisectDialog(context);
      },
    ),
    GitCommand(
      titleKey: 'commandViewReflog',
      descriptionKey: 'commandViewReflogDesc',
      icon: PhosphorIconsRegular.clockCounterClockwise,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        await showReflogDialog(context);
      },
    ),
    GitCommand(
      titleKey: 'commandCherryPickCommit',
      descriptionKey: 'commandCherryPickCommitDesc',
      icon: PhosphorIconsRegular.arrowBendDownRight,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        await BaseDialog.show(
          context: context,
          dialog: BaseDialog(
            title: l10n.cherryPickCommitDialog,
            icon: PhosphorIconsRegular.arrowBendDownRight,
            content: BodyMediumLabel(l10n.cherryPickCommitInstructions),
            actions: [
              BaseButton(
                label: l10n.ok,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    ),
    GitCommand(
      titleKey: 'commandRevertCommit',
      descriptionKey: 'commandRevertCommitDesc',
      icon: PhosphorIconsRegular.arrowCounterClockwise,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        await BaseDialog.show(
          context: context,
          dialog: BaseDialog(
            title: l10n.revertCommitDialog,
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            content: BodyMediumLabel(l10n.revertCommitInstructions),
            actions: [
              BaseButton(
                label: l10n.ok,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    ),
    GitCommand(
      titleKey: 'commandResetToCommit',
      descriptionKey: 'commandResetToCommitDesc',
      icon: PhosphorIconsRegular.arrowCounterClockwise,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        await BaseDialog.show(
          context: context,
          dialog: BaseDialog(
            title: l10n.resetToCommitDialog,
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            content: BodyMediumLabel(l10n.resetToCommitInstructions),
            actions: [
              BaseButton(
                label: l10n.ok,
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    ),
    GitCommand(
      titleKey: 'commandCleanWorkingDirectory',
      descriptionKey: 'commandCleanWorkingDirectoryDesc',
      icon: PhosphorIconsRegular.broom,
      category: CommandCategory.advanced,
      onExecute: (context, ref) async {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;

        // First show what would be removed (dry run)
        final gitService = ref.read(gitServiceProvider);
        if (gitService == null) return;

        try {
          // Run dry run to see what would be removed
          await gitService.cleanWorkingDirectory(
            dryRun: true,
            directories: true,
          );

          if (!context.mounted) return;

          final confirmed = await BaseDialog.show<bool>(
            context: context,
            dialog: BaseDialog(
              title: l10n.cleanWorkingDirectoryDialog,
              icon: PhosphorIconsRegular.warningCircle,
              variant: DialogVariant.destructive,
              content: BodyMediumLabel(l10n.cleanWorkingDirectoryConfirm),
              actions: [
                BaseButton(
                  label: l10n.cancel,
                  variant: ButtonVariant.tertiary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                BaseButton(
                  label: l10n.clean,
                  variant: ButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await ref
                .read(gitActionsProvider)
                .cleanWorkingDirectory(force: true, directories: true);
          }
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            if (l10n != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.failedToCleanWorkingDirectory(e.toString()),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
      },
    ),

    // ========================================
    // Settings
    // ========================================
    GitCommand(
      titleKey: 'commandOpenSettings',
      descriptionKey: 'commandOpenSettingsDesc',
      icon: PhosphorIconsRegular.gear,
      category: CommandCategory.settings,
      shortcut: 'Ctrl+,',
      onExecute: (context, ref) {
        ref.read(navigationDestinationProvider.notifier).state =
            AppDestination.settings;
      },
    ),
    GitCommand(
      titleKey: 'commandConfigureDiffTools',
      descriptionKey: 'commandConfigureDiffToolsDesc',
      icon: PhosphorIconsRegular.gitDiff,
      category: CommandCategory.settings,
      onExecute: (context, ref) async {
        await showDiffToolsConfigDialog(context);
      },
    ),
  ];

  // TODO: Add remaining 250+ commands
  // This is a sample showing the structure
  // Full implementation would include all operations from the legacy app
}
