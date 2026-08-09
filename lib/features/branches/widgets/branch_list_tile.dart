import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/dialogs/confirm_destructive.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/branch.dart';
import '../../../core/git/destructive_action.dart';
import '../../../core/services/services.dart';
import '../dialogs/rename_branch_dialog.dart';
import '../dialogs/merge_branch_dialog.dart';
import '../dialogs/delete_branch_dialog.dart';

/// Individual branch list tile with actions and status
class BranchListTile extends ConsumerWidget {
  final GitBranch branch;
  final bool isLocal;

  /// Whether the list's roving highlight rests on this row.
  final bool isHighlighted;

  /// Whether the list holding this row owns keyboard focus, so the highlight
  /// renders as a focus ring rather than the muted resting tint.
  final bool containerHasFocus;

  const BranchListTile({
    super.key,
    required this.branch,
    required this.isLocal,
    this.isHighlighted = false,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return BaseListItem(
      isSelected: isHighlighted,
      containerHasFocus: containerHasFocus,
      // The row's leading mark stays a raw `Icon` because its WEIGHT is the
      // statement: Bold when this is the branch you are on, Regular otherwise,
      // which `icon_weight_census_test.dart` records as one of the places
      // where the weight IS the meaning. `IconRole` deliberately cannot carry
      // a weight, so `BaseIcon` would draw the current branch at the same
      // stroke as every other row and drop the distinction inside a rename.
      // The colour is stranded with it: a `Tone` reaches a mark only through
      // `BaseIcon`. Both leave together when the skin re-decides the weight on
      // its side of the seam - and the accent this spells out is the same word
      // the branch name beside it already says as `Tone.accent`.
      leading: Icon(
        branch.isCurrent
            ? PhosphorIconsBold.gitBranch
            : PhosphorIconsRegular.gitBranch,
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
                    ? BaseLabel(
                        branch.shortName,
                        role: TextRole.itemTitle,
                        // "This is the branch you are on" - the one configured,
                        // active thing in the list, which is what Tone.accent
                        // says. The colour it lands on under Material is the
                        // same `colorScheme.primary` this site spelled out.
                        tone: Tone.accent,
                      )
                    : BaseLabel(branch.shortName, role: TextRole.body),
              ),
              if (branch.isCurrent) ...[
                const BaseGap(Proximity.related),
                BaseBadge(
                  label: AppLocalizations.of(context)!.current,
                  size: BadgeSize.small,
                  variant: BadgeVariant.primary,
                ),
              ],
              if (branch.isProtected) ...[
                const BaseGap(Proximity.related),
                // "This branch is protected", said beside the name it
                // qualifies: a dense row-level mark, which is
                // `ControlScale.compact`, and secondary to the name it sits
                // beside, which is `Tone.muted`. Material answers both with the
                // 16 pixels and the `onSurfaceVariant` this site spelled out.
                const BaseIcon(
                  IconRole.lock,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
              ],
            ],
          ),
          // Subtitle with commit message and tracking
          if (branch.lastCommitMessage != null) ...[
            // A title and the line that qualifies it are two halves of one
            // thing: `hairline`.
            const BaseGap(Proximity.hairline),
            BaseLabel(
              branch.lastCommitMessage!,
              role: TextRole.detail,
              maxLines: 1,
            ),
          ],
          if (branch.hasUpstream) ...[
            // The same relationship the line above states, said with the same
            // word rather than with a second number: this row and the one it
            // follows are two halves of one description of the branch.
            const BaseGap(Proximity.hairline),
            Row(
              children: [
                // The inline-metadata mark beside a detail line, at the one
                // scale the whole application uses for that job. It was drawn
                // here at 12 and at 16 two screens away, which was one meaning
                // said with two numbers; `compact` is the meaning.
                const BaseIcon(
                  IconRole.arrowsLeftRight,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.hairline),
                // Three states of one branch against its remote. The middle arm
                // reached for `colorScheme.secondary` only because Material has
                // no warning role at all, which is the giveaway that a meaning
                // was being approximated with whatever slot was free; said as a
                // meaning it is Tone.warning, and the skin answers it.
                BaseLabel(
                  '${branch.upstreamBranch} ${branch.trackingStatus ?? ""}',
                  role: TextRole.detail,
                  tone: branch.isDiverged
                      ? Tone.danger
                      : branch.isBehind
                      ? Tone.warning
                      : Tone.success,
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: isLocal && !branch.isCurrent
          ? BaseIconButton(
              icon: IconRole.arrowRight,
              tooltip: AppLocalizations.of(context)!.checkout,
              onPressed: () => _checkoutBranch(context, ref),
            )
          : null,
      contextMenuItems: [
        if (isLocal && !branch.isCurrent)
          MenuAction(
            label: AppLocalizations.of(context)!.checkout,
            icon: IconRole.arrowRight,
            onPressed: () => _checkoutBranch(context, ref),
          ),
        if (isLocal && !branch.isProtected)
          MenuAction(
            label: AppLocalizations.of(context)!.rename,
            icon: IconRole.pencil,
            onPressed: () => _renameBranch(context, ref),
          ),
        if (isLocal && !branch.isCurrent)
          MenuAction(
            label: AppLocalizations.of(context)!.mergeIntoCurrent,
            icon: IconRole.gitMerge,
            onPressed: () => _mergeBranch(context, ref),
          ),
        // Checkout option for remote branches
        if (!isLocal)
          MenuAction(
            label: AppLocalizations.of(context)!.checkout,
            icon: IconRole.arrowRight,
            onPressed: () => _checkoutBranch(context, ref),
          ),
        if (!branch.isCurrent && !branch.isProtected)
          // The red tint the entry used to spell out is now derived from the
          // role, so the Material rendering can keep it and another design
          // language can express "destructive" its own way.
          MenuAction(
            label: 'Delete',
            icon: IconRole.trash,
            role: MenuActionRole.destructive,
            onPressed: () => _deleteBranch(context, ref),
          ),
      ],
    );
  }

  Future<void> _checkoutBranch(BuildContext context, WidgetRef ref) async {
    try {
      // Remote branches must be checked out by their bare name; passing the
      // remote-qualified ref would detach HEAD instead of creating a local
      // tracking branch. For local branches this is identical to shortName.
      await ref
          .read(gitActionsProvider)
          .switchBranch(branch.branchNameWithoutRemote);
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to checkout: $e');
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
        await ref
            .read(gitActionsProvider)
            .renameBranch(result, oldName: branch.shortName);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to rename: $e');
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
            NotificationService.showError(context, 'Merge failed: $e');
          }
        }
      }
    }
  }

  Future<void> _deleteBranch(BuildContext context, WidgetRef ref) async {
    // Deleting a remote branch destroys the ref on the server for everyone,
    // so it goes through the remote-tier gate — the user retypes the branch
    // name before the confirm enables. Protected branches (local or remote)
    // still get the dialog's explanatory refusal below.
    if (!isLocal && !branch.isProtected) {
      final remoteName = branch.remoteName;
      if (remoteName == null) return;

      final l10n = AppLocalizations.of(context)!;
      final confirmed = await confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteRemoteBranch,
        icon: IconRole.warning,
        title: l10n.deleteBranchDialog,
        message: l10n.deleteRemoteBranchConfirmMessage(
          branch.branchNameWithoutRemote,
          remoteName,
        ),
        confirmLabel: l10n.delete,
        confirmationToken: branch.branchNameWithoutRemote,
      );
      if (!confirmed || !context.mounted) return;

      try {
        await ref
            .read(gitActionsProvider)
            .deleteRemoteBranch(remoteName, branch.branchNameWithoutRemote);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to delete: $e');
        }
      }
      return;
    }

    final result = await showDialog<DeleteBranchResult>(
      context: context,
      builder: (context) => DeleteBranchDialog(branch: branch),
    );

    if (result != null &&
        result != DeleteBranchResult.cancel &&
        context.mounted) {
      try {
        final force = result == DeleteBranchResult.forceDelete;
        await ref
            .read(gitActionsProvider)
            .deleteBranch(branch.shortName, force: force);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to delete: $e');
        }
      }
    }
  }
}
