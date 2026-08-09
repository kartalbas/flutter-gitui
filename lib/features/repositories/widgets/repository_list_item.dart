import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        IconRole,
        MenuAction,
        MenuEntry,
        Proximity,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../repository_batch_error_provider.dart';
import 'sync_on_double_tap.dart';
import '../../../shared/dialogs/batch_result_dialog.dart';
import '../../../shared/components/base_layout.dart';

/// List item widget displaying a workspace repository in a compact row format
class RepositoryListItem extends ConsumerWidget {
  final WorkspaceRepository repository;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onOpenInEditor;
  final VoidCallback? onEditRemoteUrl;
  final bool isSelected;
  final bool isMultiSelected;
  final bool showCheckbox;

  /// Whether the list's roving highlight rests on this row.
  final bool isHighlighted;

  /// Whether the collection holding this row owns keyboard focus. Only the
  /// highlighted row wears the focus ring, and only while the collection is
  /// focused; the current repository keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const RepositoryListItem({
    super.key,
    required this.repository,
    required this.onTap,
    required this.onRemove,
    required this.onToggleFavorite,
    this.onToggleSelection,
    this.onOpenInEditor,
    this.onEditRemoteUrl,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.showCheckbox = false,
    this.isHighlighted = false,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = repository.isValidGitRepo;
    final status = ref.watch(repositoryStatusByPathProvider(repository.path));

    // Repository is only selectable if BOTH checks pass:
    // 1. Synchronous check: repository.isValidGitRepo
    // 2. Async status check: !status.isBroken (unless still loading)
    final isSelectable = isValid && (status.isLoading || !status.isBroken);

    return BaseListItem(
      isSelected: isSelected || isHighlighted,
      isMultiSelected: isMultiSelected,
      isSelectable: isSelectable,
      // The focus ring belongs to the roving highlight alone; the current
      // repository keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
      onTap: onTap,
      leading: (showCheckbox && isSelectable)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Multi-selection checkbox
                Checkbox(
                  value: isMultiSelected,
                  onChanged: onToggleSelection != null
                      ? (_) => onToggleSelection!()
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const BaseGap(Proximity.related),
              ],
            )
          : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository name
          Row(
            children: [
              Flexible(
                // The selected-container pairing is gone from every label on
                // this row: the row paints the selected container and
                // publishes the matching foreground through its
                // DefaultTextStyle, and a label that restated it was saying
                // the surface's answer for it.
                child: BaseLabel(
                  repository.displayName,
                  role: TextRole.itemTitle,
                  maxLines: 1,
                ),
              ),

              // Status badges or loading indicator
              const BaseGap(Proximity.related),

              // Batch operation result icon
              _buildBatchResultIcon(context, ref),

              // Double-clicking the badges syncs this one repository, matching
              // the card view - the row showing "↓2" is where the user wants
              // to act on it.
              SyncOnDoubleTap(
                repository: repository,
                onSingleTap: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show loading while analyzing
                    if (status.isGitNotConfigured) ...[
                      // A setting the user has to supply before git will
                      // commit at all: "this may not be what you intended".
                      _buildCompactBadge(
                        context,
                        IconRole.gear,
                        BadgeVariant.warning,
                        label: 'Git not configured',
                      ),
                    ] else if (status.isLoading) ...[
                      // The colour is GONE rather than translated: it was
                      // Material's own answer copied back onto the widget that
                      // had already given it, not a meaning this row was
                      // stating. `CircularProgressIndicator` resolves
                      // `valueColor ?? color ?? ProgressIndicatorTheme.color ??
                      // defaults.color`; this application installs no
                      // `ProgressIndicatorTheme` and every M3 default class
                      // answers `defaults.color` with `colorScheme.primary`, so
                      // the deleted line and the ambient default hand the
                      // painter the same Color - measured in both themes. See
                      // the twin in `repository_card.dart` for the full note.
                      //
                      // The box and the stroke stay, because those are this
                      // row's own statements and no facade can carry them; they
                      // leave with `controls.progress` at the inline extent,
                      // which is also where a spinner first gets a way to say a
                      // tone.
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ] else ...[
                      // Broken
                      if (status.isBroken)
                        _buildCompactBadge(
                          context,
                          IconRole.warningCircle,
                          BadgeVariant.danger,
                          label: 'Broken',
                        ),

                      // Behind (pull)
                      if (status.hasIncoming) ...[
                        const BaseGap(Proximity.hairline),
                        // Worth knowing and nothing is wrong. The arrow and
                        // the count are what tell it from the pill below, and
                        // they always were: Material answers `info` and
                        // `primary` with one role, a collapse the contract
                        // records rather than hides.
                        _buildCompactBadge(
                          context,
                          IconRole.arrowDown,
                          BadgeVariant.info,
                          label: '↓${status.commitsBehind}',
                        ),
                      ],

                      // Ahead (push)
                      if (status.hasOutgoing) ...[
                        const BaseGap(Proximity.hairline),
                        _buildCompactBadge(
                          context,
                          IconRole.arrowUp,
                          BadgeVariant.primary,
                          label: '↑${status.commitsAhead}',
                        ),
                      ],

                      // Uncommitted
                      if (status.hasUncommittedChanges) ...[
                        const BaseGap(Proximity.hairline),
                        // Tracked files whose content differs from the index,
                        // which is the git palette's modified colour by
                        // definition rather than a scheme role picked for
                        // contrast.
                        _buildCompactBadge(
                          context,
                          IconRole.pencilSimple,
                          BadgeVariant.warning,
                          label: 'Changes',
                        ),
                      ],

                      // Clean status. Only claimed once the remote has actually been
                      // contacted: the ahead/behind counts come from the local
                      // remote-tracking refs, which a fetch is what moves.
                      if (!status.isBroken &&
                          !status.hasIncoming &&
                          !status.hasOutgoing &&
                          !status.hasUncommittedChanges &&
                          status.exists &&
                          status.isValidGit) ...[
                        const BaseGap(Proximity.hairline),
                        if (status.needsSignIn)
                          _buildCompactBadge(
                            context,
                            IconRole.signIn,
                            BadgeVariant.warning,
                            label: 'Sign-in required',
                          )
                        else if (status.isRemoteUnreachable)
                          _buildCompactBadge(
                            context,
                            IconRole.cloudSlash,
                            BadgeVariant.neutral,
                            label: 'Unreachable',
                          )
                        else if (status.remoteCheckFailedUnknown)
                          _buildCompactBadge(
                            context,
                            IconRole.warningCircle,
                            BadgeVariant.danger,
                            label: 'Check failed',
                          )
                        else if (status.isRemoteUnchecked)
                          _buildCompactBadge(
                            context,
                            IconRole.clockCountdown,
                            BadgeVariant.neutral,
                            label: 'Not checked',
                          )
                        else
                          // "This finished, and it finished well" is what a
                          // repository in sync with its remote says.
                          _buildCompactBadge(
                            context,
                            IconRole.checkCircle,
                            BadgeVariant.success,
                            label: 'Up to date',
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
          const BaseGap(Proximity.hairline),

          // Branch and path
          Row(
            children: [
              // Current branch. "This is the branch the repository is on"
              // is `Tone.accent`, exactly as branch_list_tile.dart:66 says it
              // for the identical fact; losing it here left the same meaning
              // with two different answers in two rows of the same
              // application.
              if (status.currentBranch != null) ...[
                BaseIcon(
                  IconRole.gitBranch,
                  scale: ControlScale.compact,
                  tone: Tone.accent,
                ),
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  status.currentBranch!,
                  role: TextRole.detail,
                  tone: Tone.accent,
                ),
                const BaseGap(Proximity.grouped),
              ],

              // Where the remote lives, so a row that needs a sign-in also
              // says which account it would need.
              // Where the remote lives, the path and the last access are
              // the row's supporting detail: secondary to the name above
              // them, said once with `Tone.muted` for both row states. Their
              // glyphs take the `IconTheme` the row publishes
              // (base_list_item.dart:328) rather than restating the row's
              // selection state, which is what had left glyph and word in two
              // different colour systems on one line.
              if (status.remoteIdentity case final identity?) ...[
                Icon(PhosphorIconsRegular.cloud, size: AppTheme.iconXS),
                const BaseGap(Proximity.hairline),
                Tooltip(
                  message: status.remoteUrl ?? identity.host,
                  child: BaseLabel(
                    identity.accountHint == null
                        ? identity.label
                        : '${identity.label} · ${identity.accountHint}',
                    role: TextRole.detail,
                    tone: Tone.muted,
                  ),
                ),
                const BaseGap(Proximity.grouped),
              ],

              Icon(PhosphorIconsRegular.folder, size: AppTheme.iconXS),
              const BaseGap(Proximity.hairline),
              Flexible(
                child: BaseLabel(
                  repository.path,
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 1,
                ),
              ),
              const BaseGap(Proximity.grouped),
              Icon(PhosphorIconsRegular.clock, size: AppTheme.iconXS),
              const BaseGap(Proximity.hairline),
              Flexible(
                child: BaseLabel(
                  repository.lastAccessed.toDisplayString(
                    Localizations.localeOf(context).languageCode,
                  ),
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // Description
          if (repository.description != null) ...[
            const BaseGap(Proximity.hairline),
            BaseLabel(
              repository.description!,
              role: TextRole.detail,
              maxLines: 1,
            ),
          ],
        ],
      ),
      // The row's own overflow anchor, through the member that OWNS the
      // row. It used to be a Material `PopupMenuButton` welded into the
      // trailing slot beside the icon buttons, tinting its own glyph from
      // `isSelected` with a hand-picked `onPrimaryContainer` at 60% - the
      // application answering "what colour is an accessory on a selected
      // row", which is the question `surfaces.listRow` answers for every
      // accessory it publishes a foreground for. Handing the entries to the
      // component instead is the bypass repaired: the skin builds the anchor,
      // colours it for the tile it sits on, and opens the menu against it.
      contextMenuItems: <MenuEntry>[
        if (onOpenInEditor != null)
          MenuAction(
            icon: IconRole.code,
            label: AppLocalizations.of(context)!.openFolderInEditor,
            onPressed: onOpenInEditor,
          ),
        if (status.hasRemote && onEditRemoteUrl != null)
          MenuAction(
            icon: IconRole.link,
            label: AppLocalizations.of(context)!.editRemoteUrl('origin'),
            onPressed: onEditRemoteUrl,
          ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseIconButton(
            // One role, one mark; the weight is the skin's, reached
            // through `isSelected`. See repository_card.dart for the reason.
            icon: IconRole.star,
            isSelected: repository.isFavorite,
            onPressed: onToggleFavorite,
            tooltip: repository.isFavorite
                ? AppLocalizations.of(context)!.tooltipRemoveFromFavorites
                : AppLocalizations.of(context)!.tooltipAddToFavorites,
          ),
          BaseIconButton(
            icon: IconRole.trash,
            onPressed: onRemove,
            tooltip: AppLocalizations.of(context)!.tooltipRemoveFromWorkspace,
          ),
        ],
      ),
    );
  }

  Widget _buildBatchResultIcon(BuildContext context, WidgetRef ref) {
    final batchResult = ref.watch(
      repositoryBatchErrorByPathProvider(repository.path),
    );

    if (batchResult == null) {
      return const SizedBox.shrink();
    }

    final isSuccess = batchResult.success;
    // The twin of repository_card.dart's `_buildBatchResultIcon`, which
    // converted a phase earlier and left this one behind saying the same fact
    // in Material's words. `Tone.accent` resolves to the same accent role this
    // painted and `Tone.danger` to the same error role, so no pixel of colour
    // moves - deliberately NOT `Tone.success` for the happy branch, which
    // would swap the accent for the git palette's green and is a design change
    // rather than a translation.
    //
    // Two appearance changes come with it and both are measured. The mark goes
    // from 14 to the 16 dp `compact` rung: 14 is a stray literal between this
    // application's own iconXS (12) and iconS (16), and the row's height is set
    // by the `bodySmall` line box beside it (12 x 1.33 = 16), so the row does
    // not grow. And the Bold stroke does not survive - the card's twin already
    // recorded why at length: the weight was identical on both branches of the
    // ternary, so it was never what told success from failure. Recorded in
    // test/shared/icons/icon_weight_census_test.dart.
    //
    // The mark's trailing space was a one-sided padding, which is a gap
    // wearing a padding idiom. The enclosing row cannot own it, because it
    // does not know whether this builder returned a mark or nothing, so the
    // mark and its gap travel together.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => _showBatchResultDialog(context, ref, batchResult),
          child: BaseIcon(
            isSuccess ? IconRole.checkCircle : IconRole.warningCircle,
            scale: ControlScale.compact,
            tone: isSuccess ? Tone.accent : Tone.danger,
          ),
        ),
        const BaseGap(Proximity.hairline),
      ],
    );
  }

  void _showBatchResultDialog(
    BuildContext context,
    WidgetRef ref,
    RepositoryBatchResult result,
  ) {
    showBatchResultDialog(
      context: context,
      repositoryName: repository.displayName,
      result: result,
      onDismiss: () {
        ref
            .read(repositoryBatchErrorProvider.notifier)
            .clearResult(repository.path);
      },
    );
  }

  /// One status pill, drawn by `surfaces.badge` through [BaseBadge].
  ///
  /// The twin of `repository_card.dart`'s, converted with it and for the same
  /// reason: the whole micro-surface — the pill's two washes, its 60 % edge,
  /// its corner, its 6/2 inset, the 12 px mark and the `Color` that painted
  /// all of them — is the badge member's geometry, and what the row states is
  /// only what each pill MEANS. That is what unblocks the `Color` parameter
  /// the note here used to name: there is no decoration left to resolve a
  /// tone into.
  ///
  /// `BadgeSize.small` is `ControlScale.compact`, the rung the vocabulary
  /// describes as "a chip, a row-level action". The pill grows slightly
  /// against the hand-painted copy — horizontal inset 6 → 8, mark 12 → 10,
  /// label `labelSmall` → the badge's own 10 px — and its selected 30 % wash
  /// is gone: that was the row restating its own selection on every pill
  /// inside it, and the row already says it once.
  ///
  /// [label] stays nullable because the call sites still allow a mark-only
  /// pill, and `BadgeSpec.label` is required — the empty string is what the
  /// member is handed there, which is honest about the fact that no shipping
  /// call site takes that branch today.
  Widget _buildCompactBadge(
    BuildContext context,
    IconRole icon,
    BadgeVariant variant, {
    String? label,
  }) {
    return BaseBadge(
      label: label ?? '',
      icon: icon,
      variant: variant,
      size: BadgeSize.small,
    );
  }
}
