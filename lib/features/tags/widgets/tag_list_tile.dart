import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_card.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/destructive_action.dart';
import '../../../core/git/models/tag.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/dialogs/confirm_destructive.dart';
import '../dialogs/checkout_tag_dialog.dart';
import '../dialogs/select_remote_dialog.dart';
import '../dialogs/create_branch_from_tag_dialog.dart';
import '../../history/providers/history_search_provider.dart';
import '../../history/models/history_search_filter.dart';
import '../../../core/navigation/navigation_item.dart';
import '../../../shared/components/base_layout.dart';

/// Individual tag list tile widget
class TagListTile extends ConsumerWidget {
  final GitTag tag;
  final bool selectionMode;
  final bool isSelected;
  final bool isLocalOnly;
  final bool hasRemotes;
  final Function(bool)? onSelectionChanged;

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

  const TagListTile({
    super.key,
    required this.tag,
    this.selectionMode = false,
    this.isSelected = false,
    this.isLocalOnly = false,
    this.hasRemotes = false,
    this.onSelectionChanged,
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
        // The roving highlight wears the primary selection treatment; a
        // checked tag in selection mode wears the multi-select tint, the
        // same split the repository cards use.
        isSelected: isHighlighted,
        isMultiSelected: selectionMode && isSelected,
        containerHasFocus: containerHasFocus,
        content: selectionMode
            ? InkWell(
                onTap: () => onSelectionChanged?.call(!isSelected),
                child: BaseInset(
                  all: Inset.normal,
                  child: Row(
                    children: [
                      Icon(
                        tag.isAnnotated
                            ? PhosphorIconsBold.tag
                            : PhosphorIconsRegular.tag,
                        color: tag.isAnnotated ? context.gitColors.added : null,
                      ),
                      const BaseGap(Proximity.grouped),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: BaseLabel(
                                    tag.name,
                                    role: TextRole.itemTitle,
                                  ),
                                ),
                                if (isLocalOnly) ...[
                                  const BaseGap(Proximity.related),
                                  _buildLocalBadge(context),
                                ],
                              ],
                            ),
                            BaseLabel(
                              tag.displayMessage,
                              role: TextRole.body,
                              maxLines: 2,
                            ),
                            if (tag.date != null)
                              BaseLabel(
                                tag.dateDisplay(
                                  Localizations.localeOf(context).languageCode,
                                ),
                                role: TextRole.detail,
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
                controller: expansionController,
                onExpansionChanged: onExpansionChanged,
                initiallyExpanded: false,
                leading: Icon(
                  tag.isAnnotated
                      ? PhosphorIconsBold.tag
                      : PhosphorIconsRegular.tag,
                  color: tag.isAnnotated ? context.gitColors.added : null,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: BaseLabel(tag.name, role: TextRole.itemTitle),
                    ),
                    if (isLocalOnly) ...[
                      const BaseGap(Proximity.related),
                      _buildLocalBadge(context),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BaseLabel(
                      tag.displayMessage,
                      role: TextRole.body,
                      maxLines: 2,
                    ),
                    if (tag.date != null)
                      BaseLabel(
                        tag.dateDisplay(
                          Localizations.localeOf(context).languageCode,
                        ),
                        role: TextRole.detail,
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
                        icon: IconRole.gitBranch,
                        label: AppLocalizations.of(context)!.checkout,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'createBranch',
                      child: MenuItemContent(
                        icon: IconRole.gitBranch,
                        label: AppLocalizations.of(context)!.createBranch,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'viewInHistory',
                      child: MenuItemContent(
                        icon: IconRole.clockCounterClockwise,
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
                          icon: IconRole.upload,
                          label: AppLocalizations.of(context)!.push,
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    if (!isLocalOnly || !hasRemotes) const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      // The meaning is stated once now. `MenuItemContent.tone`
                      // wore its meaning on the MARK only, so the label had to
                      // be re-said as a raw `Color` to keep the two halves of
                      // one entry agreeing; the tone reaches the words too,
                      // and the second statement goes. Pixel-identical by
                      // construction: the component answers `Tone.danger` with
                      // the same scheme role this line spelled out.
                      child: MenuItemContent(
                        icon: IconRole.trash,
                        label: AppLocalizations.of(context)!.delete,
                        tone: Tone.danger,
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      // A badge sits barely in from its edge across, and down the page it is
      // as close to the edge as its word stays legible: the badge's height is
      // the point, because it rides beside a tag name in a list row.
      child: BaseInset(
        x: Inset.tight,
        y: Inset.hairline,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.upload,
              size: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const BaseGap(Proximity.hairline),
            Text(
              AppLocalizations.of(context)!.local,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagDetails(BuildContext context, WidgetRef ref) {
    return BaseInset(
      all: Inset.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.tagDetailsType,
            tag.isAnnotated
                ? AppLocalizations.of(context)!.tagTypeAnnotated
                : AppLocalizations.of(context)!.tagTypeLightweight,
            IconRole.tag,
          ),
          const BaseGap(Proximity.related),
          _buildDetailRow(
            context,
            AppLocalizations.of(context)!.tagDetailsCommit,
            tag.shortHash,
            IconRole.gitCommit,
          ),
          if (tag.displayTagger != null) ...[
            const BaseGap(Proximity.related),
            _buildDetailRow(
              context,
              AppLocalizations.of(context)!.tagDetailsTagger,
              tag.displayTagger!,
              IconRole.user,
            ),
          ],
          if (tag.date != null) ...[
            const BaseGap(Proximity.related),
            _buildDetailRow(
              context,
              AppLocalizations.of(context)!.tagDetailsDate,
              tag.dateDisplay(Localizations.localeOf(context).languageCode),
              IconRole.calendar,
            ),
          ],
          if (tag.message != null && tag.message!.isNotEmpty) ...[
            const BaseGap(Proximity.grouped),
            const BaseSeparator(),
            const BaseGap(Proximity.related),
            BaseLabel(
              AppLocalizations.of(context)!.tagDetailsMessage,
              role: TextRole.detail,
            ),
            const BaseGap(Proximity.related),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                all: Inset.normal,
                // An annotated tag's message is quoted verbatim from the
                // repository, so its line breaks and its alignment are part
                // of what it says - which is what TextRole.code names. The
                // monospace family this site spelled out was one design
                // language's answer to that, and the user's own choice of
                // diff font now reaches it through the skin.
                child: BaseLabel(
                  tag.message!,
                  role: TextRole.code,
                  selectable: true,
                ),
              ),
            ),
          ],
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
          label: AppLocalizations.of(context)!.checkout,
          variant: ButtonVariant.secondary,
          leadingIcon: IconRole.gitBranch,
          onPressed: () => _checkoutTag(context, ref),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.createBranch,
          variant: ButtonVariant.secondary,
          leadingIcon: IconRole.gitBranch,
          onPressed: () => _createBranchFromTag(context, ref),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.viewCommitInHistory,
          variant: ButtonVariant.secondary,
          leadingIcon: IconRole.clockCounterClockwise,
          onPressed: () => _viewCommitInHistory(context, ref),
        ),
        // Only show push button if tag is unpushed and we have remotes
        if (isLocalOnly && hasRemotes)
          BaseButton(
            label: AppLocalizations.of(context)!.push,
            variant: ButtonVariant.secondary,
            leadingIcon: IconRole.upload,
            onPressed: () => _pushTag(context, ref),
          ),
        BaseButton(
          label: AppLocalizations.of(context)!.delete,
          variant: ButtonVariant.dangerSecondary,
          leadingIcon: IconRole.trash,
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
            // The notice's own FILL, not a foreground: the tone mapping is
            // about what a mark or a word MEANS, and this paints the pill the
            // words sit on. It waits for `overlays.notify`, because a tone may
            // only be resolved inside the notice host's `build` - a call site
            // has no host, and the application is deliberately given no way to
            // turn a `Tone` into a `Color` for its own decoration.
            //
            // Underneath the read sits the real defect: all five notices in
            // this file are `NotificationService.showError` and `.showSuccess`
            // written out by hand. Adopting the service is what deletes them,
            // and it is a behaviour change (the error service never
            // auto-dismisses and adds a copy affordance) rather than a rename,
            // so it is reported instead of folded in here.
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
            // The same fill as the checkout failure above, one meaning over:
            // a notice that succeeded rather than one that failed, waiting for
            // the same member.
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarFailedToCreateBranch(e.toString())),
            // The same fill as the checkout failure above, waiting for the
            // same member.
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
                // The same fill as the checkout failure above, waiting for the
                // same member.
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
    // Capture localization strings before async operations.
    final l10n = AppLocalizations.of(context)!;
    // A tag that also lives on a remote is a remote-tier delete that always
    // confirms; a local-only tag is reflog-recoverable and runs under the
    // master destructive switch.
    final confirmed = await confirmDestructive(
      context: context,
      ref: ref,
      action: willDeleteFromRemote
          ? DestructiveAction.deleteRemoteTag
          : DestructiveAction.deleteLocalTag,
      icon: IconRole.warningCircle,
      title: l10n.dialogTitleDeleteTag,
      // Without remotes the tag can only be deleted locally, so the message
      // must not claim it will also be removed from a remote.
      message: willDeleteFromRemote
          ? l10n.dialogContentDeleteTagRemote(tag.name)
          : l10n.dialogContentDeleteTagLocal(tag.name),
      confirmLabel: l10n.delete,
      // For the remote tier the gate makes the user retype the tag's name
      // before the confirm enables; the recoverable local tier ignores it.
      confirmationToken: tag.name,
    );

    if (confirmed && context.mounted) {
      // Deleting a tag off a server is destructive, so the target remote is
      // picked explicitly instead of guessed, just like the push flow. It is
      // resolved before the operation starts so a cancelled picker leaves the
      // tag untouched instead of deleting it locally only.
      String? remoteName;
      if (willDeleteFromRemote) {
        remoteName = remotes.length == 1
            ? remotes.first
            : await showDialog<String>(
                context: context,
                builder: (context) => SelectRemoteDialog(remotes: remotes),
              );
        if (remoteName == null || !context.mounted) return;
      }

      // Deleting the tag refreshes the list and unmounts this very tile, after
      // which WidgetRef throws. The notifier outlives the tile, so hold it
      // directly to guarantee the progress overlay is always cleared.
      final progress = ref.read(progressProvider.notifier);

      try {
        // Start progress tracking
        progress.startOperation(
          willDeleteFromRemote
              ? l10n.progressDeletingTagLocalRemote
              : l10n.progressDeletingTag,
          willDeleteFromRemote ? 3 : 2,
        );

        // Delete local tag (this will auto-refresh)
        progress.updateProgress(
          1,
          statusMessage: l10n.progressDeletingTagLocally(tag.name),
        );
        await ref.read(gitActionsProvider).deleteTag(tag.name);

        // Delete from remote if tag was synced (this will also auto-refresh)
        if (remoteName != null) {
          progress.updateProgress(
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
        progress.updateProgress(
          willDeleteFromRemote ? 3 : 2,
          statusMessage: l10n.progressUpdatingList,
        );

        // Wait a bit for git operations to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // The delete already refreshed the list, which unmounts this tile once
        // its tag is gone; the invalidation is then redundant and ref would
        // throw, taking the progress completion below down with it.
        if (context.mounted) {
          // Manually invalidate all related providers
          ref.invalidate(tagsProvider);
          ref.invalidate(localOnlyTagsProvider);
          ref.invalidate(remoteOnlyTagsProvider);
        }

        // Complete progress
        progress.completeOperation();
      } catch (e) {
        // Complete progress on error
        progress.completeOperation();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToDeleteTag(e.toString())),
              // The same fill as the checkout failure above, waiting for the
              // same member.
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
