import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_card.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/destructive_action.dart';
import '../../../core/git/models/stash.dart';
import '../../../shared/dialogs/confirm_destructive.dart';
import '../dialogs/create_branch_from_stash_dialog.dart';
import '../dialogs/stash_diff_dialog.dart';
import '../../../shared/components/base_layout.dart';

/// Individual stash list tile with expansion and action buttons
class StashListTile extends ConsumerWidget {
  final GitStash stash;

  /// Whether the list's roving highlight rests on this row.
  final bool isHighlighted;

  /// Whether the list holding this row owns keyboard focus, so the highlight
  /// renders as a focus ring rather than the muted resting tint.
  final bool containerHasFocus;

  /// Expansion state owned by the hosting screen, so the keyboard can toggle
  /// the details of the highlighted row.
  final ExpansibleController? expansionController;

  /// Reports a header toggle, letting the screen move its highlight to the
  /// row the pointer acted on.
  final ValueChanged<bool>? onExpansionChanged;

  const StashListTile({
    super.key,
    required this.stash,
    this.isHighlighted = false,
    this.containerHasFocus = true,
    this.expansionController,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseInset(
      x: Inset.normal,
      y: Inset.tight,
      child: BaseCard(
        inset: Inset.none,
        isSelected: isHighlighted,
        containerHasFocus: containerHasFocus,
        content: ExpansionTile(
          controller: expansionController,
          onExpansionChanged: onExpansionChanged,
          leading: CircleAvatar(
            backgroundColor: stash.isLatest
                ? context.gitColors.added.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            // Tone.accent, not the git-added green this badge used to borrow:
            // the latest stash is not "added", it is the one `git stash pop`
            // will take, which is exactly what the accent says.
            child: BaseLabel(
              stash.index.toString(),
              role: TextRole.micro,
              tone: stash.isLatest ? Tone.accent : Tone.neutral,
            ),
          ),
          title: BaseLabel(stash.displayTitle, role: TextRole.itemTitle),
          subtitle: BaseLabel(
            'on ${stash.branch} • ${stash.timestampDisplay(Localizations.localeOf(context).languageCode)}',
            role: TextRole.detail,
            tone: Tone.muted,
          ),
          trailing: BasePopupMenuButton<String>(
            icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'apply',
                child: MenuItemContent(
                  icon: IconRole.arrowBendDownLeft,
                  label: AppLocalizations.of(context)!.apply,
                ),
              ),
              PopupMenuItem(
                value: 'pop',
                child: MenuItemContent(
                  icon: IconRole.arrowBendUpLeft,
                  label: AppLocalizations.of(context)!.pop,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'branch',
                child: MenuItemContent(
                  icon: IconRole.gitBranch,
                  label: AppLocalizations.of(context)!.menuItemCreateBranch,
                ),
              ),
              PopupMenuItem(
                value: 'diff',
                child: MenuItemContent(
                  icon: IconRole.gitDiff,
                  label: AppLocalizations.of(context)!.menuItemViewDiff,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'drop',
                // The same statement twice, for the reason tag_list_tile.dart
                // records: the meaning is `Tone.danger`, and `MenuItemContent`
                // wears its tone on the MARK only, painting its label from a
                // raw `Color?`. Deleting the read greys the destructive label,
                // which is a change of appearance rather than a rename.
                child: MenuItemContent(
                  icon: IconRole.trash,
                  label: AppLocalizations.of(context)!.drop,
                  tone: Tone.danger,
                  labelColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          children: [_buildStashDetails(context, ref)],
        ),
      ),
    );
  }

  Widget _buildStashDetails(BuildContext context, WidgetRef ref) {
    return BaseInset(
      all: Inset.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.reference,
            stash.ref,
            IconRole.tag,
          ),
          const BaseGap(Proximity.related),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.createBranch,
            stash.branch,
            IconRole.gitBranch,
          ),
          const BaseGap(Proximity.related),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.commit,
            stash.shortHash,
            IconRole.gitCommit,
          ),
          const BaseGap(Proximity.related),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.created,
            stash.timestampDisplay(
              Localizations.localeOf(context).languageCode,
            ),
            IconRole.clock,
          ),
          const BaseGap(Proximity.grouped),
          _buildActionButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconRole icon,
  ) {
    return Row(
      children: [
        // The row's mark, resolved by the skin. Muted at the compact scale is
        // exactly what this row drew before the conversion - 16 logical
        // pixels in `onSurfaceVariant` - so the swap changes the vocabulary,
        // not a pixel.
        BaseIcon(icon, tone: Tone.muted, scale: ControlScale.compact),
        const BaseGap(Proximity.related),
        BaseLabel('$label:', role: TextRole.detail, tone: Tone.muted),
        const BaseGap(Proximity.related),
        Expanded(child: BaseLabel(value, role: TextRole.body)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppTheme.paddingS,
      runSpacing: AppTheme.paddingS,
      children: [
        BaseButton(
          onPressed: () => _applyStash(context, ref),
          leadingIcon: IconRole.arrowBendDownLeft,
          label: AppLocalizations.of(context)!.apply,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _popStash(context, ref),
          leadingIcon: IconRole.arrowBendUpLeft,
          label: AppLocalizations.of(context)!.pop,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _showDiff(context, ref),
          leadingIcon: IconRole.gitDiff,
          label: AppLocalizations.of(context)!.diff,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _createBranch(context, ref),
          leadingIcon: IconRole.gitBranch,
          label: AppLocalizations.of(context)!.branch,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'apply':
        _applyStash(context, ref);
        break;
      case 'pop':
        _popStash(context, ref);
        break;
      case 'branch':
        _createBranch(context, ref);
        break;
      case 'diff':
        _showDiff(context, ref);
        break;
      case 'drop':
        _confirmDropStash(context, ref);
        break;
    }
  }

  Future<void> _applyStash(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gitActionsProvider).applyStash(stash.ref);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToApplyStash(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _popStash(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(gitActionsProvider)
          .popStash(stash.ref, expectedHash: stash.hash);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToPopStash(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showDiff(BuildContext context, WidgetRef ref) async {
    try {
      if (context.mounted) {
        await showStashDiffDialog(context, stash: stash);
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToLoadDiff(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createBranch(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CreateBranchFromStashDialog(stash: stash),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      try {
        await ref.read(gitActionsProvider).branchFromStash(result, stash.ref);
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToCreateBranch(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDropStash(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.dropStash,
      icon: IconRole.warningCircle,
      title: l10n.dropStashDialog,
      message: l10n.dropStashConfirm(stash.ref),
      confirmLabel: l10n.drop,
    );

    if (confirmed && context.mounted) {
      try {
        await ref
            .read(gitActionsProvider)
            .dropStash(stash.ref, expectedHash: stash.hash);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToDropStash(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
