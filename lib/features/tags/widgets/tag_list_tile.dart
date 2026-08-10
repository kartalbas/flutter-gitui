import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_pressable.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
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
            ? BasePressable(
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
                // The trigger, its position and the menu opened against it
                // are the skin's through `overlays.menuAnchor`. The tile used
                // to build Material's `PopupMenuButton`, render each row as a
                // `PopupMenuItem` and then translate the chosen string back
                // into the callback it came from; each entry carries its own
                // action now, and the anchor carries the name every mark-only
                // control owes - the hand-built one had none.
                trailing: Overlays.anchor(
                  spec: MenuAnchorSpec(
                    icon: IconRole.dotsThreeVertical,
                    tooltip: AppLocalizations.of(context)!.moreActions,
                  ),
                  entries: <MenuEntry>[
                    MenuAction(
                      icon: IconRole.gitBranch,
                      label: AppLocalizations.of(context)!.checkout,
                      onPressed: () => _checkoutTag(context, ref),
                    ),
                    MenuAction(
                      icon: IconRole.gitBranch,
                      label: AppLocalizations.of(context)!.createBranch,
                      onPressed: () => _createBranchFromTag(context, ref),
                    ),
                    MenuAction(
                      icon: IconRole.clockCounterClockwise,
                      label: AppLocalizations.of(context)!.viewCommitInHistory,
                      onPressed: () => _viewCommitInHistory(context, ref),
                    ),
                    // Only show push option if tag is unpushed and we have
                    // remotes
                    if (isLocalOnly && hasRemotes) ...[
                      MenuAction(
                        icon: IconRole.upload,
                        label: AppLocalizations.of(context)!.push,
                        onPressed: () => _pushTag(context, ref),
                      ),
                      const MenuSeparator(),
                    ],
                    if (!isLocalOnly || !hasRemotes) const MenuSeparator(),
                    // It says what it MEANS - deleting a tag destroys it -
                    // and the skin decides how a destructive row reads.
                    MenuAction(
                      icon: IconRole.trash,
                      label: AppLocalizations.of(context)!.delete,
                      role: MenuActionRole.destructive,
                      onPressed: () => _confirmDeleteTag(context, ref),
                    ),
                  ],
                ),
                children: [_buildTagDetails(context, ref)],
              ),
      ),
    );
  }

  /// "This tag exists only here", said beside the name it qualifies.
  ///
  /// It is the same statement `branch_list_tile.dart` already makes through
  /// `surfaces.badge` for the branch you are on - a dense, row-level pill in
  /// the accent - and it used to be hand-painted here at its own measure: a
  /// `primaryContainer` fill, a 4 dp corner, a 12 dp glyph and a bold
  /// `labelSmall`. One meaning drawn two ways is the drift a member exists to
  /// end, so the pill's whole measure is the skin's now and the two agree by
  /// construction. The corner went with the fill it belonged to rather than
  /// being restated: a badge's corner is derived from its own height in the
  /// skin, which is why no rung is named here.
  Widget _buildLocalBadge(BuildContext context) {
    return BaseBadge(
      label: AppLocalizations.of(context)!.local,
      icon: IconRole.upload,
      variant: BadgeVariant.primary,
      size: BadgeSize.small,
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
            // The tinted box round the tag's own message was a card drawn by
            // hand - a fill and an 8 dp corner and nothing else - and it is
            // the same surface `commit_details_panel.dart` paints round a
            // commit's message for the same reason: **here is the one
            // self-contained thing this detail view is about**, set apart from
            // the rows of metadata around it. It becomes the same member, so
            // the two message surfaces cannot round differently again.
            BaseCard(
              isSelectable: false,
              inset: Inset.normal,
              // An annotated tag's message is quoted verbatim from the
              // repository, so its line breaks and its alignment are part
              // of what it says - which is what TextRole.code names. The
              // monospace family this site spelled out was one design
              // language's answer to that, and the user's own choice of
              // diff font now reaches it through the skin.
              content: BaseLabel(
                tag.message!,
                role: TextRole.code,
                selectable: true,
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

  /// Everything the user can do to this tag, as one run of equals.
  ///
  /// The statement is a row of related actions that is allowed to run onto a
  /// second line when the panel is narrow - which is what `layout.row(wrap:
  /// true)` says - so the distance between two buttons, and the distance
  /// between two lines of them, are the skin's single answer to "these belong
  /// together" instead of the two hand-written 8s that stood here. The buttons
  /// are all one height, so the run's cross alignment is not visible; it is
  /// stated as `start` because that is what the bare `Wrap` did and this
  /// conversion changes vocabulary, not a pixel.
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.layout.row(
        inner,
        [
          ContentPort(
            BaseButton(
              label: AppLocalizations.of(context)!.checkout,
              variant: ButtonVariant.secondary,
              leadingIcon: IconRole.gitBranch,
              onPressed: () => _checkoutTag(context, ref),
            ),
          ),
          ContentPort(
            BaseButton(
              label: AppLocalizations.of(context)!.createBranch,
              variant: ButtonVariant.secondary,
              leadingIcon: IconRole.gitBranch,
              onPressed: () => _createBranchFromTag(context, ref),
            ),
          ),
          ContentPort(
            BaseButton(
              label: AppLocalizations.of(context)!.viewCommitInHistory,
              variant: ButtonVariant.secondary,
              leadingIcon: IconRole.clockCounterClockwise,
              onPressed: () => _viewCommitInHistory(context, ref),
            ),
          ),
          // Only show push button if tag is unpushed and we have remotes
          if (isLocalOnly && hasRemotes)
            ContentPort(
              BaseButton(
                label: AppLocalizations.of(context)!.push,
                variant: ButtonVariant.secondary,
                leadingIcon: IconRole.upload,
                onPressed: () => _pushTag(context, ref),
              ),
            ),
          ContentPort(
            BaseButton(
              label: AppLocalizations.of(context)!.delete,
              variant: ButtonVariant.dangerSecondary,
              leadingIcon: IconRole.trash,
              onPressed: () => _confirmDeleteTag(context, ref),
            ),
          ),
        ],
        gap: Proximity.related,
        cross: CrossAxisAlignment.start,
        wrap: true,
      );
    });
  }

  Future<void> _checkoutTag(BuildContext context, WidgetRef ref) async {
    final confirmed = await CheckoutTagDialog.show(context, tagName: tag.name);

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(gitActionsProvider).checkoutTag(tag.name);
        if (!context.mounted) return;
      } catch (e) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        // The fill left with the surface: the site states what happened and
        // the skin resolves the tone inside its own notice host.
        //
        // What did NOT change is the mechanism these five notices use. They
        // are `NotificationService.showError` and `.showSuccess` written out
        // by hand, so the failures auto-dismiss, carry no mark and offer no
        // copy affordance where the service's errors do all three. That
        // disagreement is #418, and adopting the service here would be that
        // redesign rather than this conversion.
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: l10n.snackbarFailedToCheckoutTag(e.toString()),
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
        // One meaning over from the checkout failure above: a branch that
        // exists now, which is what `success` says.
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.success,
            title: l10n.snackbarBranchCreatedSuccess(branchName),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: l10n.snackbarFailedToCreateBranch(e.toString()),
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
          : await Overlays.dialogFrom<String>(
              context,
              route: DialogRouteSpec(
                title: AppLocalizations.of(context)!.selectRemoteDialog,
              ),
              builder: (context) => SelectRemoteDialog(remotes: remotes),
            );

      if (remoteName != null && context.mounted) {
        try {
          await ref.read(gitActionsProvider).pushTag(remoteName, tag.name);
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            Overlays.notify(
              context,
              NoticeSpec(
                tone: Tone.danger,
                title: l10n.snackbarFailedToPushTag(e.toString()),
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
            : await Overlays.dialogFrom<String>(
                context,
                route: DialogRouteSpec(
                  title: AppLocalizations.of(context)!.selectRemoteDialog,
                ),
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
          Overlays.notify(
            context,
            NoticeSpec(
              tone: Tone.danger,
              title: l10n.snackbarFailedToDeleteTag(e.toString()),
            ),
          );
        }
      }
    }
  }
}
