import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_card.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/stash.dart';
import '../dialogs/create_branch_from_stash_dialog.dart';
import '../dialogs/drop_stash_dialog.dart';
import '../dialogs/stash_diff_dialog.dart';

/// Individual stash list tile with expansion and action buttons
class StashListTile extends ConsumerWidget {
  final GitStash stash;

  const StashListTile({super.key, required this.stash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingS,
      ),
      child: BaseCard(
        padding: EdgeInsets.zero,
        content: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: stash.isLatest
                ? AppTheme.gitAdded.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TitleSmallLabel(
              stash.index.toString(),
              color: stash.isLatest
                  ? AppTheme.gitAdded
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          title: TitleMediumLabel(stash.displayTitle),
          subtitle: BodySmallLabel(
            'on ${stash.branch} • ${stash.timestampDisplay(Localizations.localeOf(context).languageCode)}',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          trailing: BasePopupMenuButton<String>(
            icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'apply',
                child: MenuItemContent(
                  icon: PhosphorIconsRegular.arrowBendDownLeft,
                  label: AppLocalizations.of(context)!.apply,
                ),
              ),
              PopupMenuItem(
                value: 'pop',
                child: MenuItemContent(
                  icon: PhosphorIconsRegular.arrowBendUpLeft,
                  label: AppLocalizations.of(context)!.pop,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'branch',
                child: MenuItemContent(
                  icon: PhosphorIconsRegular.gitBranch,
                  label: AppLocalizations.of(context)!.menuItemCreateBranch,
                ),
              ),
              PopupMenuItem(
                value: 'diff',
                child: MenuItemContent(
                  icon: PhosphorIconsRegular.gitDiff,
                  label: AppLocalizations.of(context)!.menuItemViewDiff,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'drop',
                child: MenuItemContent(
                  icon: PhosphorIconsRegular.trash,
                  label: AppLocalizations.of(context)!.drop,
                  iconColor: Theme.of(context).colorScheme.error,
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
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.reference,
            stash.ref,
            PhosphorIconsRegular.tag,
          ),
          const SizedBox(height: AppTheme.paddingS),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.createBranch,
            stash.branch,
            PhosphorIconsRegular.gitBranch,
          ),
          const SizedBox(height: AppTheme.paddingS),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.commit,
            stash.shortHash,
            PhosphorIconsRegular.gitCommit,
          ),
          const SizedBox(height: AppTheme.paddingS),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.created,
            stash.timestampDisplay(
              Localizations.localeOf(context).languageCode,
            ),
            PhosphorIconsRegular.clock,
          ),
          const SizedBox(height: AppTheme.paddingM),
          _buildActionButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTheme.paddingS),
        BodySmallLabel(
          '$label:',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTheme.paddingS),
        Expanded(child: BodyMediumLabel(value)),
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
          leadingIcon: PhosphorIconsRegular.arrowBendDownLeft,
          label: AppLocalizations.of(context)!.apply,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _popStash(context, ref),
          leadingIcon: PhosphorIconsRegular.arrowBendUpLeft,
          label: AppLocalizations.of(context)!.pop,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _showDiff(context, ref),
          leadingIcon: PhosphorIconsRegular.gitDiff,
          label: AppLocalizations.of(context)!.diff,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
        ),
        BaseButton(
          onPressed: () => _createBranch(context, ref),
          leadingIcon: PhosphorIconsRegular.gitBranch,
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
      await ref.read(gitActionsProvider).popStash(stash.ref);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DropStashDialog(stash: stash),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(gitActionsProvider).dropStash(stash.ref);
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
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
