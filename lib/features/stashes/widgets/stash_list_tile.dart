import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_card.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/destructive_action.dart';
import '../../../core/git/models/stash.dart';
import '../../../shared/dialogs/confirm_destructive.dart';
import '../dialogs/create_branch_from_stash_dialog.dart';
import '../dialogs/stash_diff_dialog.dart';
import '../../../shared/components/base_layout.dart';
import '../../../core/services/notification_service.dart';

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
          // The trigger and the menu it opens are the skin's, through
          // `overlays.menuAnchor`. What this tile used to do instead was a
          // three-part hand-build: a Material `PopupMenuButton` for the
          // trigger, `PopupMenuItem` widgets for the rows, and a string switch
          // to turn the chosen value back into the callback it came from. All
          // three go: each entry now carries its own action, and the anchor
          // carries the name every mark-only control owes - it had none.
          trailing: Overlays.anchor(
            spec: MenuAnchorSpec(
              icon: IconRole.dotsThreeVertical,
              tooltip: AppLocalizations.of(context)!.moreActions,
            ),
            entries: <MenuEntry>[
              MenuAction(
                icon: IconRole.arrowBendDownLeft,
                label: AppLocalizations.of(context)!.apply,
                onPressed: () => _applyStash(context, ref),
              ),
              MenuAction(
                icon: IconRole.arrowBendUpLeft,
                label: AppLocalizations.of(context)!.pop,
                onPressed: () => _popStash(context, ref),
              ),
              const MenuSeparator(),
              MenuAction(
                icon: IconRole.gitBranch,
                label: AppLocalizations.of(context)!.menuItemCreateBranch,
                onPressed: () => _createBranch(context, ref),
              ),
              MenuAction(
                icon: IconRole.gitDiff,
                label: AppLocalizations.of(context)!.menuItemViewDiff,
                onPressed: () => _showDiff(context, ref),
              ),
              const MenuSeparator(),
              // It says what it MEANS - dropping a stash destroys it - and
              // the skin decides how a destructive row reads.
              MenuAction(
                icon: IconRole.trash,
                label: AppLocalizations.of(context)!.drop,
                role: MenuActionRole.destructive,
                onPressed: () => _confirmDropStash(context, ref),
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

  /// Everything the user can do to this stash, as one run of equals.
  ///
  /// The same statement the tag tile makes: a row of related actions that may
  /// run onto a second line when the panel is narrow, so both the distance
  /// between two buttons and the distance between two lines of them are the
  /// skin's one answer rather than the two hand-written 8s that stood here.
  /// The buttons are all one height, so the run's cross alignment is not
  /// visible; `start` is stated because that is what the bare `Wrap` did.
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.layout.row(
        inner,
        [
          ContentPort(
            BaseButton(
              onPressed: () => _applyStash(context, ref),
              leadingIcon: IconRole.arrowBendDownLeft,
              label: AppLocalizations.of(context)!.apply,
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
            ),
          ),
          ContentPort(
            BaseButton(
              onPressed: () => _popStash(context, ref),
              leadingIcon: IconRole.arrowBendUpLeft,
              label: AppLocalizations.of(context)!.pop,
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
            ),
          ),
          ContentPort(
            BaseButton(
              onPressed: () => _showDiff(context, ref),
              leadingIcon: IconRole.gitDiff,
              label: AppLocalizations.of(context)!.diff,
              variant: ButtonVariant.secondary,
              size: ButtonSize.small,
            ),
          ),
          ContentPort(
            BaseButton(
              onPressed: () => _createBranch(context, ref),
              leadingIcon: IconRole.gitBranch,
              label: AppLocalizations.of(context)!.branch,
              variant: ButtonVariant.secondary,
              size: ButtonSize.small,
            ),
          ),
        ],
        gap: Proximity.related,
        cross: CrossAxisAlignment.start,
        wrap: true,
      );
    });
  }

  Future<void> _applyStash(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gitActionsProvider).applyStash(stash.ref);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        // The fill left with the surface: the site states what happened and
        // the skin resolves the tone inside its own notice host.
        //
        // What did NOT change is the mechanism these five notices use. They
        // are still `NotificationService.showError` written out by hand, so
        // they auto-dismiss, carry no mark and offer no copy affordance where
        // the service's errors do all three. That disagreement is #418, and
        // adopting the service here would be that redesign rather than this
        // conversion.
        NotificationService.showError(
          context,
          l10n.snackbarFailedToApplyStash(e.toString()),
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
        NotificationService.showError(
          context,
          l10n.snackbarFailedToPopStash(e.toString()),
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
        NotificationService.showError(
          context,
          l10n.snackbarFailedToLoadDiff(e.toString()),
        );
      }
    }
  }

  Future<void> _createBranch(BuildContext context, WidgetRef ref) async {
    final result = await Overlays.dialogFrom<String>(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.createBranchFromStash,
      ),
      builder: (context) => CreateBranchFromStashDialog(stash: stash),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      try {
        await ref.read(gitActionsProvider).branchFromStash(result, stash.ref);
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          NotificationService.showError(
            context,
            l10n.snackbarFailedToCreateBranch(e.toString()),
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
          NotificationService.showError(
            context,
            l10n.snackbarFailedToDropStash(e.toString()),
          );
        }
      }
    }
  }
}
