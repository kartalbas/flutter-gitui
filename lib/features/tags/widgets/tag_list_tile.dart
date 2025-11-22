import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_card.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/tag.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/logger_service.dart';
import '../dialogs/checkout_tag_dialog.dart';
import '../dialogs/select_remote_dialog.dart';
import '../dialogs/create_branch_from_tag_dialog.dart';
import '../../history/providers/history_search_provider.dart';
import '../../history/models/history_search_filter.dart';
import '../../../core/navigation/navigation_item.dart';

/// Individual tag list tile widget
class TagListTile extends ConsumerWidget {
  final GitTag tag;
  final bool selectionMode;
  final bool isSelected;
  final bool isLocalOnly;
  final bool hasRemotes;
  final Function(bool)? onSelectionChanged;

  const TagListTile({
    super.key,
    required this.tag,
    this.selectionMode = false,
    this.isSelected = false,
    this.isLocalOnly = false,
    this.hasRemotes = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingS,
      ),
      child: BaseCard(
        padding: EdgeInsets.zero,
        content: selectionMode
            ? InkWell(
                onTap: () => onSelectionChanged?.call(!isSelected),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  child: Row(
                    children: [
                      Icon(
                        tag.isAnnotated
                            ? PhosphorIconsBold.tag
                            : PhosphorIconsRegular.tag,
                        color: tag.isAnnotated ? AppTheme.gitAdded : null,
                      ),
                      const SizedBox(width: AppTheme.paddingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(child: TitleMediumLabel(tag.name)),
                                if (isLocalOnly) ...[
                                  const SizedBox(width: AppTheme.paddingS),
                                  _buildLocalBadge(context),
                                ],
                              ],
                            ),
                            BodyMediumLabel(
                              tag.displayMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tag.date != null)
                              BodySmallLabel(
                                tag.dateDisplay(
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ExpansionTile(
                key: ValueKey(tag.name),
                initiallyExpanded: false,
                leading: Icon(
                  tag.isAnnotated
                      ? PhosphorIconsBold.tag
                      : PhosphorIconsRegular.tag,
                  color: tag.isAnnotated ? AppTheme.gitAdded : null,
                ),
                title: Row(
                  children: [
                    Flexible(child: TitleMediumLabel(tag.name)),
                    if (isLocalOnly) ...[
                      const SizedBox(width: AppTheme.paddingS),
                      _buildLocalBadge(context),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BodyMediumLabel(
                      tag.displayMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tag.date != null)
                      BodySmallLabel(
                        tag.dateDisplay(
                          Localizations.localeOf(context).languageCode,
                        ),
                      ),
                  ],
                ),
                trailing: BasePopupMenuButton<String>(
                  icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
                  onSelected: (value) => _handleMenuAction(context, ref, value),
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem(
                      value: 'checkout',
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.gitBranch,
                        label: AppLocalizations.of(context)!.checkout,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'createBranch',
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.gitBranch,
                        label: AppLocalizations.of(context)!.createBranch,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'viewInHistory',
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.clockCounterClockwise,
                        label: AppLocalizations.of(
                          context,
                        )!.viewCommitInHistory,
                      ),
                    ),
                    // Only show push option if tag is unpushed and we have remotes
                    if (isLocalOnly && hasRemotes) ...[
                      PopupMenuItem(
                        value: 'push',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.upload,
                          label: AppLocalizations.of(context)!.push,
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    if (!isLocalOnly || !hasRemotes) const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.trash,
                        label: AppLocalizations.of(context)!.delete,
                        iconColor: Theme.of(context).colorScheme.error,
                        labelColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                children: [_buildTagDetails(context, ref)],
              ),
      ),
    );
  }

  Widget _buildLocalBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.upload,
            size: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            AppLocalizations.of(context)!.local,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagDetails(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.tagDetailsType,
            tag.isAnnotated
                ? AppLocalizations.of(context)!.tagTypeAnnotated
                : AppLocalizations.of(context)!.tagTypeLightweight,
            PhosphorIconsRegular.tag,
          ),
          const SizedBox(height: AppTheme.paddingS),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.tagDetailsCommit,
            tag.shortHash,
            PhosphorIconsRegular.gitCommit,
          ),
          if (tag.displayTagger != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            _buildDetailRow(
              context,
              AppLocalizations.of(context)!.tagDetailsTagger,
              tag.displayTagger!,
              PhosphorIconsRegular.user,
            ),
          ],
          if (tag.date != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            _buildDetailRow(
              context,
              AppLocalizations.of(context)!.tagDetailsDate,
              tag.dateDisplay(Localizations.localeOf(context).languageCode),
              PhosphorIconsRegular.calendar,
            ),
          ],
          if (tag.message != null && tag.message!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.paddingM),
            const Divider(),
            const SizedBox(height: AppTheme.paddingS),
            LabelMediumLabel(AppLocalizations.of(context)!.tagDetailsMessage),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                tag.message!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
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
          label: AppLocalizations.of(context)!.checkout,
          variant: ButtonVariant.secondary,
          leadingIcon: PhosphorIconsRegular.gitBranch,
          onPressed: () => _checkoutTag(context, ref),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.createBranch,
          variant: ButtonVariant.secondary,
          leadingIcon: PhosphorIconsRegular.gitBranch,
          onPressed: () => _createBranchFromTag(context, ref),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.viewCommitInHistory,
          variant: ButtonVariant.secondary,
          leadingIcon: PhosphorIconsRegular.clockCounterClockwise,
          onPressed: () => _viewCommitInHistory(context, ref),
        ),
        // Only show push button if tag is unpushed and we have remotes
        if (isLocalOnly && hasRemotes)
          BaseButton(
            label: AppLocalizations.of(context)!.push,
            variant: ButtonVariant.secondary,
            leadingIcon: PhosphorIconsRegular.upload,
            onPressed: () => _pushTag(context, ref),
          ),
        BaseButton(
          label: AppLocalizations.of(context)!.delete,
          variant: ButtonVariant.dangerSecondary,
          leadingIcon: PhosphorIconsRegular.trash,
          onPressed: () => _confirmDeleteTag(context, ref),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'checkout':
        _checkoutTag(context, ref);
        break;
      case 'createBranch':
        _createBranchFromTag(context, ref);
        break;
      case 'viewInHistory':
        _viewCommitInHistory(context, ref);
        break;
      case 'push':
        _pushTag(context, ref);
        break;
      case 'delete':
        _confirmDeleteTag(context, ref);
        break;
    }
  }

  Future<void> _checkoutTag(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CheckoutTagDialog(tagName: tag.name),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(gitActionsProvider).checkoutTag(tag.name);
        if (!context.mounted) return;
      } catch (e) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToCheckoutTag(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createBranchFromTag(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateBranchFromTagDialog(tagName: tag.name),
    );

    if (result != null && context.mounted) {
      final branchName = result['branchName'] as String;
      final checkout = result['checkout'] as bool;
      final l10n = AppLocalizations.of(context)!;

      try {
        await ref
            .read(gitActionsProvider)
            .createBranch(branchName, startPoint: tag.name, checkout: checkout);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarBranchCreatedSuccess(branchName)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToCreateBranch(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _viewCommitInHistory(BuildContext context, WidgetRef ref) {
    Logger.debug('[TagListTile] View in history clicked for tag: ${tag.name}');

    // Set search filter to search by tag
    ref.read(historySearchFilterProvider.notifier).state = HistorySearchFilter(
      tags: [tag.name],
    );
    Logger.debug('[TagListTile] Set search filter for tag: ${tag.name}');

    // Navigate to history view
    ref.read(navigationDestinationProvider.notifier).state =
        AppDestination.history;
    Logger.debug('[TagListTile] Navigated to history');
  }

  Future<void> _pushTag(BuildContext context, WidgetRef ref) async {
    final remotes = await ref.read(remoteNamesProvider.future);

    if (remotes.isEmpty) {
      return;
    }

    if (context.mounted) {
      final remoteName = remotes.length == 1
          ? remotes.first
          : await showDialog<String>(
              context: context,
              builder: (context) => SelectRemoteDialog(remotes: remotes),
            );

      if (remoteName != null && context.mounted) {
        try {
          await ref.read(gitActionsProvider).pushTag(remoteName, tag.name);
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.snackbarFailedToPushTag(e.toString())),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _confirmDeleteTag(BuildContext context, WidgetRef ref) async {
    // Check if we have remotes
    final remotes = await ref.read(remoteNamesProvider.future);
    final hasRemotes = remotes.isNotEmpty;

    // Determine if tag exists on remote (not local-only)
    final willDeleteFromRemote = !isLocalOnly && hasRemotes;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.warningCircle,
        title: AppLocalizations.of(context)!.dialogTitleDeleteTag,
        content: Text(
          isLocalOnly
              ? AppLocalizations.of(
                  context,
                )!.dialogContentDeleteTagLocal(tag.name)
              : AppLocalizations.of(
                  context,
                )!.dialogContentDeleteTagRemote(tag.name),
        ),
        variant: DialogVariant.destructive,
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

    if (confirmed == true && context.mounted) {
      // Capture localization strings before async operations
      final l10n = AppLocalizations.of(context)!;
      final remoteName = remotes.contains('origin') ? 'origin' : remotes.first;

      try {
        // Start progress tracking
        ref
            .read(progressProvider.notifier)
            .startOperation(
              willDeleteFromRemote
                  ? l10n.progressDeletingTagLocalRemote
                  : l10n.progressDeletingTag,
              willDeleteFromRemote ? 3 : 2,
            );

        // Delete local tag (this will auto-refresh)
        ref
            .read(progressProvider.notifier)
            .updateProgress(
              1,
              statusMessage: l10n.progressDeletingTagLocally(tag.name),
            );
        await ref.read(gitActionsProvider).deleteTag(tag.name);

        // Delete from remote if tag was synced (this will also auto-refresh)
        if (willDeleteFromRemote) {
          ref
              .read(progressProvider.notifier)
              .updateProgress(
                2,
                statusMessage: l10n.progressDeletingTagFromRemote(
                  tag.name,
                  remoteName,
                ),
              );
          await ref
              .read(gitActionsProvider)
              .deleteRemoteTag(remoteName, tag.name);
        }

        // Force a final refresh to ensure UI updates
        ref
            .read(progressProvider.notifier)
            .updateProgress(
              willDeleteFromRemote ? 3 : 2,
              statusMessage: l10n.progressUpdatingList,
            );

        // Wait a bit for git operations to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Manually invalidate all related providers
        ref.invalidate(tagsProvider);
        ref.invalidate(localOnlyTagsProvider);
        ref.invalidate(remoteOnlyTagsProvider);

        // Complete progress
        ref.read(progressProvider.notifier).completeOperation();
      } catch (e) {
        // Complete progress on error
        ref.read(progressProvider.notifier).completeOperation();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToDeleteTag(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
