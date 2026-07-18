import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/branch.dart';
import '../../../core/services/services.dart';
import '../dialogs/rename_branch_dialog.dart';
import '../dialogs/merge_branch_dialog.dart';
import '../dialogs/delete_branch_dialog.dart';

/// Individual branch list tile with actions and status
class BranchListTile extends ConsumerWidget {
  final GitBranch branch;
  final bool isLocal;

  const BranchListTile({
    super.key,
    required this.branch,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return BaseListItem(
      leading: Icon(
        branch.isCurrent ? PhosphorIconsBold.gitBranch : PhosphorIconsRegular.gitBranch,
        color: branch.isCurrent ? colorScheme.primary : null,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with branch name and badges
          Row(
            children: [
              Flexible(
                child: branch.isCurrent
                    ? TitleSmallLabel(
                        branch.shortName,
                        color: colorScheme.primary,
                      )
                    : BodyMediumLabel(
                        branch.shortName,
                      ),
              ),
              if (branch.isCurrent) ...[
                const SizedBox(width: AppTheme.paddingS),
                BaseBadge(
                  label: AppLocalizations.of(context)!.current,
                  size: BadgeSize.small,
                  variant: BadgeVariant.primary,
                ),
              ],
              if (branch.isProtected) ...[
                const SizedBox(width: AppTheme.paddingS),
                Icon(
                  PhosphorIconsRegular.lock,
                  size: AppTheme.iconS,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          // Subtitle with commit message and tracking
          if (branch.lastCommitMessage != null) ...[
            const SizedBox(height: AppTheme.paddingXS),
            BodySmallLabel(
              branch.lastCommitMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (branch.hasUpstream) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.arrowsLeftRight,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                BodySmallLabel(
                  '${branch.upstreamBranch} ${branch.trackingStatus ?? ""}',
                  color: branch.isDiverged
                      ? colorScheme.error
                      : branch.isBehind
                          ? colorScheme.secondary
                          : AppTheme.gitAdded,
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: isLocal && !branch.isCurrent
          ? BaseIconButton(
              icon: PhosphorIconsRegular.arrowRight,
              tooltip: AppLocalizations.of(context)!.checkout,
              onPressed: () => _checkoutBranch(context, ref),
            )
          : null,
      contextMenuItems: [
        if (isLocal && !branch.isCurrent)
          PopupMenuItem(
            value: 'checkout',
            child: MenuItemContent(
              icon: PhosphorIconsRegular.arrowRight,
              label: AppLocalizations.of(context)!.checkout,
            ),
            onTap: () => _checkoutBranch(context, ref),
          ),
        if (isLocal && !branch.isProtected)
          PopupMenuItem(
            value: 'rename',
            child: MenuItemContent(
              icon: PhosphorIconsRegular.pencil,
              label: AppLocalizations.of(context)!.rename,
            ),
            onTap: () => _renameBranch(context, ref),
          ),
        if (isLocal && !branch.isCurrent)
          PopupMenuItem(
            value: 'merge',
            child: MenuItemContent(
              icon: PhosphorIconsRegular.gitMerge,
              label: AppLocalizations.of(context)!.mergeIntoCurrent,
            ),
            onTap: () => _mergeBranch(context, ref),
          ),
        // Checkout option for remote branches
        if (!isLocal)
          PopupMenuItem(
            value: 'checkout',
            child: MenuItemContent(
              icon: PhosphorIconsRegular.arrowRight,
              label: AppLocalizations.of(context)!.checkout,
            ),
            onTap: () => _checkoutBranch(context, ref),
          ),
        if (!branch.isCurrent && !branch.isProtected)
          PopupMenuItem(
            value: 'delete',
            child: MenuItemContent(
              icon: PhosphorIconsRegular.trash,
              label: 'Delete',
              iconColor: colorScheme.error,
              labelColor: colorScheme.error,
            ),
            onTap: () => _deleteBranch(context, ref),
          ),
      ],
    );
  }

  Future<void> _checkoutBranch(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gitActionsProvider).switchBranch(branch.shortName);
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to checkout: $e',
        );
      }
    }
  }

  Future<void> _renameBranch(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => RenameBranchDialog(branch: branch),
    );

    if (result != null && context.mounted) {
      try {
        await ref.read(gitActionsProvider).renameBranch(result, oldName: branch.shortName);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to rename: $e',
          );
        }
      }
    }
  }

  Future<void> _mergeBranch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => MergeBranchDialog(branch: branch),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(gitActionsProvider).mergeBranch(branch.shortName);
      } catch (e) {
        if (context.mounted) {
          final errorMessage = e.toString().toLowerCase();

          // Detect merge conflicts
          if (errorMessage.contains('conflict') ||
              errorMessage.contains('merge conflict') ||
              errorMessage.contains('conflicting')) {
            NotificationService.showError(
              context,
              'Merge conflict detected! Please resolve conflicts in the Changes tab.',
            );
          }
          // Detect uncommitted changes preventing merge
          else if (errorMessage.contains('uncommitted') ||
                   errorMessage.contains('working tree') ||
                   errorMessage.contains('dirty')) {
            NotificationService.showError(
              context,
              'Cannot merge: You have uncommitted changes. Commit or stash them first.',
            );
          }
          // Generic merge error
          else {
            NotificationService.showError(
              context,
              'Merge failed: $e',
            );
          }
        }
      }
    }
  }

  Future<void> _deleteBranch(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<DeleteBranchResult>(
      context: context,
      builder: (context) => DeleteBranchDialog(branch: branch),
    );

    if (result != null && result != DeleteBranchResult.cancel && context.mounted) {
      try {
        final force = result == DeleteBranchResult.forceDelete;

        if (isLocal) {
          await ref.read(gitActionsProvider).deleteBranch(branch.shortName, force: force);
        } else {
          final remoteName = branch.remoteName;
          if (remoteName != null) {
            await ref.read(gitActionsProvider).deleteRemoteBranch(
                  remoteName,
                  branch.branchNameWithoutRemote,
                );
          }
        }
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to delete: $e',
          );
        }
      }
    }
  }
}
