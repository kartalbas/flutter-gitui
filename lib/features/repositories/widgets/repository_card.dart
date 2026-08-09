import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        ControlScale,
        IconRole,
        Inset,
        MenuAction,
        MenuAnchorSpec,
        MenuEntry,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/repository_status.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../repository_batch_error_provider.dart';
import '../../../shared/dialogs/batch_result_dialog.dart';
import 'sync_on_double_tap.dart';
import '../../../shared/components/base_layout.dart';

/// Card widget displaying a workspace repository
class RepositoryCard extends ConsumerWidget {
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

  /// Whether the grid's roving highlight rests on this card.
  final bool isHighlighted;

  /// Whether the collection holding this card owns keyboard focus. Only the
  /// highlighted card wears the focus ring, and only while the collection is
  /// focused; the current repository keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const RepositoryCard({
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

    return BaseCard(
      isSelected: isSelected || isHighlighted,
      isMultiSelected: isMultiSelected,
      isSelectable: isSelectable,
      // The focus ring belongs to the roving highlight alone; the current
      // repository keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
      onTap: onTap,
      // Both washes stay. A 10 % tint is a FILL - the card's own background -
      // and a fill is what a surface is made of, so it leaves with the card
      // when the card becomes a member rather than ahead of it. It is also
      // unsayable today by construction: `BaseCard.customBackgroundColor` is
      // typed as a `Color`, and only a skin may resolve a `Tone` into one.
      customBackgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : isMultiSelected
          ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with favorite and remove buttons
          Row(
            children: [
              // Multi-selection checkbox. Its trailing space was a one-sided
              // `EdgeInsets.only(right:)`, which is a gap wearing a padding
              // idiom - the distance belongs between the box and what follows
              // it, so the run states it rather than the box.
              if (showCheckbox && isSelectable) ...<Widget>[
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
              const Spacer(),
              // Batch operation result icon
              _buildBatchResultIcon(context, ref),
              BaseIconButton(
                // One role, one mark. The solid-versus-outline difference
                // this drew by hand is a WEIGHT, and a weight is the skin's
                // decision (#249 conflict C3): `isSelected` carries the fact
                // across the seam, and the skin answers it.
                icon: IconRole.star,
                isSelected: repository.isFavorite,
                onPressed: onToggleFavorite,
                tooltip: repository.isFavorite
                    ? AppLocalizations.of(context)!.tooltipRemoveFromFavorites
                    : AppLocalizations.of(context)!.tooltipAddToFavorites,
              ),
              // Repository menu
              if (onOpenInEditor != null ||
                  (status.hasRemote && onEditRemoteUrl != null))
                // The trigger and the menu it opens are one thing, and both
                // halves are the skin's through `overlays.menuAnchor`. This
                // card used to build Material's own `PopupMenuButton`, render
                // the rows itself and dispatch the chosen value back through a
                // string switch - application code performing skin geometry and
                // then re-deriving its own callback table from it. The card now
                // states only what each entry means and what it does.
                Overlays.anchor(
                  spec: MenuAnchorSpec(
                    icon: IconRole.dotsThreeVertical,
                    tooltip: AppLocalizations.of(context)!.moreActions,
                  ),
                  entries: <MenuEntry>[
                    if (onOpenInEditor != null)
                      MenuAction(
                        icon: IconRole.code,
                        label: AppLocalizations.of(context)!.openFolderInEditor,
                        onPressed: onOpenInEditor,
                      ),
                    if (status.hasRemote && onEditRemoteUrl != null)
                      MenuAction(
                        icon: IconRole.link,
                        label: AppLocalizations.of(
                          context,
                        )!.editRemoteUrl('origin'),
                        onPressed: onEditRemoteUrl,
                      ),
                  ],
                ),
              BaseIconButton(
                icon: IconRole.trash,
                onPressed: onRemove,
                tooltip: AppLocalizations.of(
                  context,
                )!.tooltipRemoveFromWorkspace,
              ),
            ],
          ),
          const BaseGap(Proximity.grouped),

          // Repository name
          // The selected-container pairing is gone from every label on this
          // card: the card paints the selected container and publishes the
          // matching foreground through its DefaultTextStyle, and a label
          // that restated it was saying the surface's answer for it.
          BaseLabel(
            repository.displayName,
            role: TextRole.itemTitle,
            maxLines: 1,
          ),
          const BaseGap(Proximity.related),

          // Path
          Row(
            children: [
              // NOT converted, and the review put it back after a conversion
              // shipped it 2 dp larger. This mark is 14 px, a size the card
              // states four times over (here, the branch, the remote and the
              // clock below) and `ControlScale` cannot say: `compact` is the
              // 16 dp rung, so `BaseIcon` here is rule 1's exact violation -
              // a meaning rounded onto the nearest available word, silently,
              // inside a colour rename. The colour is stranded with the size,
              // because a tone reaches a mark only through `BaseIcon` - and
              // the selected branch of it is itself contested: a selected
              // card paints `customBackgroundColor` (primary at 10 %), so the
              // `onSecondaryContainer` read answers a surface `BaseCard`
              // never paints (base_card.dart:160-168). Both questions - the
              // 14 px measure and the metadata row's selected foreground -
              // belong to the card member and move to P5 as one piece.
              Icon(
                PhosphorIconsRegular.folder,
                size: 14,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const BaseGap(Proximity.hairline),
              Flexible(
                child: BaseLabel(
                  repository.path,
                  role: TextRole.detail,
                  maxLines: 2,
                ),
              ),
            ],
          ),

          // Current branch
          if (status.currentBranch != null) ...[
            const BaseGap(Proximity.related),
            Row(
              children: [
                // Left raw with the folder mark above: 14 px is on no
                // `ControlScale` rung, and the colour cannot cross the seam
                // without the size. See the survivor note on the path row.
                Icon(
                  PhosphorIconsRegular.gitBranch,
                  size: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const BaseGap(Proximity.hairline),
                Flexible(
                  child: BaseLabel(
                    status.currentBranch!,
                    role: TextRole.body,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],

          // Where the remote lives. With a workspace spanning providers this is
          // what tells the user which account a repository needs - decisive
          // when its check failed for missing credentials.
          if (status.remoteIdentity case final identity?) ...[
            const BaseGap(Proximity.related),
            Row(
              children: [
                // Left raw with the folder mark above: 14 px is on no
                // `ControlScale` rung, and the colour cannot cross the seam
                // without the size. See the survivor note on the path row.
                Icon(
                  PhosphorIconsRegular.cloud,
                  size: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const BaseGap(Proximity.hairline),
                Flexible(
                  child: Tooltip(
                    message: status.remoteUrl ?? identity.host,
                    child: BaseLabel(
                      identity.accountHint == null
                          ? identity.label
                          : '${identity.label} · ${identity.accountHint}',
                      role: TextRole.detail,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Description if available
          if (repository.description != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(
              repository.description!,
              role: TextRole.body,
              maxLines: 2,
            ),
          ],

          // Status badges - show loading or actual status
          const BaseGap(Proximity.grouped),
          if (status.isGitNotConfigured)
            _buildStatusBadge(
              context,
              PhosphorIconsRegular.gear,
              'Git not configured',
              Theme.of(context).colorScheme.tertiary,
              isSelected,
            )
          else if (status.isLoading)
            // Show loading indicator while analyzing
            Row(
              children: [
                // The spinner stands in for the status mark beside it, so its
                // box is GLYPH geometry and not a spacing rung; it was spelled
                // with a padding token, which said nothing true about it. It
                // moves into `controls.progress` at the inline extent, where a
                // number is legal.
                //
                // The colour is GONE rather than translated, and the
                // difference matters: it was not a meaning this screen was
                // stating, it was Material's own answer copied back onto the
                // widget that had already given it. `CircularProgressIndicator`
                // resolves `valueColor ?? color ?? ProgressIndicatorTheme.color
                // ?? defaults.color`, this application installs no
                // `ProgressIndicatorTheme` (measured: the resolved theme colour
                // is null under both `AppTheme.lightTheme()` and
                // `darkTheme()`), and every M3 default class answers
                // `defaults.color` with `colorScheme.primary` - so the line
                // deleted here and the ambient default handed the painter the
                // same Color in both themes. This is the spinner's form of the
                // redundant `copyWith(color: colorScheme.onSurface)` that
                // `avoid_text_with_style` now flags: restating the ambient
                // answer is the defect, and removing it moves no pixel.
                //
                // What stays is the geometry alone - the box and the stroke -
                // because those really are this card's statements and neither
                // `BaseLabel` nor `BaseIcon` can carry them. They leave when
                // `controls.progress` lands at the inline extent, which is also
                // where a spinner first gets a way to say a tone at all.
                const SizedBox(
                  width: AppTheme.iconS,
                  height: AppTheme.iconS,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const BaseGap(Proximity.related),
                BaseLabel('Analyzing...', role: TextRole.detail),
              ],
            )
          else
            // Show actual status badges after analysis. Double-clicking them
            // syncs this one repository, which is where a user looking at
            // "↓2" wants to act.
            SyncOnDoubleTap(
              repository: repository,
              onSingleTap: onTap,
              // The badges are one run of equals that breaks onto a second line
              // inside the tile, which is what `layout.row(wrap: true)` says.
              // The two 4s written here said the same closeness twice - between
              // two badges and between two lines of them - and the member
              // answers both with the one rung. Stated `start`, which is what
              // the bare `Wrap` did; the badges are one height, so it moves
              // nothing.
              child: SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.layout.row(
                  inner,
                  [
                    // Broken status
                    if (status.isBroken)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          PhosphorIconsRegular.warningCircle,
                          'Broken',
                          Theme.of(context).colorScheme.error,
                          isSelected,
                        ),
                      ),

                    // Commits behind (need to pull)
                    if (status.hasIncoming)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          PhosphorIconsRegular.arrowDown,
                          '↓${status.commitsBehind}',
                          Theme.of(context).colorScheme.tertiary,
                          isSelected,
                        ),
                      ),

                    // Commits ahead (need to push)
                    if (status.hasOutgoing)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          PhosphorIconsRegular.arrowUp,
                          '↑${status.commitsAhead}',
                          Theme.of(context).colorScheme.primary,
                          isSelected,
                        ),
                      ),

                    // Uncommitted changes
                    if (status.hasUncommittedChanges)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          PhosphorIconsRegular.pencilSimple,
                          'Changes',
                          Theme.of(context).colorScheme.secondary,
                          isSelected,
                        ),
                      ),

                    // Nothing outstanding. The remote-tracking refs only move
                    // on a fetch, so claiming to be in sync before one has
                    // happened would report a clean state that was never
                    // verified. A repository the check could not reach says why
                    // instead, and the one case the user can resolve offers to
                    // do it.
                    if (!status.isBroken &&
                        !status.hasIncoming &&
                        !status.hasOutgoing &&
                        !status.hasUncommittedChanges &&
                        status.exists &&
                        status.isValidGit)
                      ContentPort(
                        _buildVerificationBadge(
                          context,
                          ref,
                          status,
                          isSelected,
                        ),
                      ),
                  ],
                  gap: Proximity.hairline,
                  cross: CrossAxisAlignment.start,
                  wrap: true,
                );
              }),
            ),

          const Spacer(),

          // Invalid repo warning
          if (!isValid) ...[
            const BaseGap(Proximity.grouped),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: BaseInset(
                all: Inset.tight,
                child: Row(
                  children: [
                    // The mark now says what the sentence beside it already
                    // said. `AppTheme.iconS` is the 16 dp rung `compact`
                    // resolves to, so nothing moves; the fill and the corner
                    // of the box around it stay behind, because a container is
                    // a surface and surfaces leave in P5.
                    BaseIcon(
                      IconRole.warningCircle,
                      scale: ControlScale.compact,
                      tone: Tone.danger,
                    ),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        'Invalid or missing repository',
                        role: TextRole.detail,
                        tone: Tone.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Last accessed
          const BaseGap(Proximity.grouped),
          Row(
            children: [
              // Left raw with the folder mark above: 14 px is on no
              // `ControlScale` rung, and the colour cannot cross the seam
              // without the size. See the survivor note on the path row.
              Icon(
                PhosphorIconsRegular.clock,
                size: 14,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const BaseGap(Proximity.hairline),
              BaseLabel(
                '${AppLocalizations.of(context)!.accessed} ${repository.lastAccessed.toDisplayString(Localizations.localeOf(context).languageCode)}',
                role: TextRole.detail,
              ),
            ],
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
    // Both marks were drawn at Phosphor BOLD before the conversion and now
    // take the ordinary stroke: an `IconButtonSpec` carries `selected`, which
    // is a state, and nothing here is a state — the weight was the same on
    // both branches of the ternary. The application draws this same
    // "how did the operation end" mark at BOTH weights already:
    // `git_output_dialog.dart` and `batch_operation_progress_dialog.dart:392`
    // draw it at the ordinary stroke while `batch_result_dialog.dart` and
    // `batch_operation_progress_dialog.dart:254` draw it bold, so the heavier
    // stroke was never carrying the meaning. Recorded and pinned by
    // `test/shared/icons/icon_weight_census_test.dart`.
    final icon = isSuccess ? IconRole.checkCircle : IconRole.warningCircle;

    // The mark's trailing space was a one-sided padding, which is a gap
    // wearing a padding idiom. It cannot move to the enclosing header row,
    // because that row does not know whether this builder returned a mark or
    // nothing at all - so the mark carries its own gap and the pair travels
    // together.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BaseIconButton(
          icon: icon,
          onPressed: () => _showBatchResultDialog(context, ref, batchResult),
          tooltip: isSuccess ? 'Operation successful' : 'Operation failed',
        ),
        const BaseGap(Proximity.related),
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

  /// The badge for a repository with nothing outstanding.
  ///
  /// "Up to date" is only claimed once the remote was actually contacted.
  /// Otherwise the badge names what stopped the check, because a repository
  /// that silently sits on "not checked" tells the user nothing and offers
  /// nothing to do. The missing-credentials case is the one they can resolve,
  /// so it is a button: pressing it fetches that one repository *with* prompts
  /// allowed, which is legitimate because they asked for it.
  Widget _buildVerificationBadge(
    BuildContext context,
    WidgetRef ref,
    RepositoryStatus status,
    bool isSelected,
  ) {
    if (status.needsSignIn) {
      return Tooltip(
        message: 'This repository needs a sign-in. Click to authenticate.',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          onTap: () => _signIn(context, ref),
          child: _buildStatusBadge(
            context,
            PhosphorIconsRegular.signIn,
            'Sign-in required',
            Theme.of(context).colorScheme.tertiary,
            isSelected,
          ),
        ),
      );
    }

    if (status.isRemoteUnreachable) {
      return Tooltip(
        message: 'The remote could not be reached. It will be retried.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.cloudSlash,
          'Unreachable',
          Theme.of(context).colorScheme.onSurfaceVariant,
          isSelected,
        ),
      );
    }

    if (status.remoteCheckFailedUnknown) {
      return Tooltip(
        message: 'The remote check failed. See the command log for details.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.warningCircle,
          'Check failed',
          Theme.of(context).colorScheme.error,
          isSelected,
        ),
      );
    }

    if (status.isRemoteUnchecked) {
      return Tooltip(
        message: 'Not compared against the remote yet.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.clockCountdown,
          'Not checked',
          Theme.of(context).colorScheme.onSurfaceVariant,
          isSelected,
        ),
      );
    }

    return _buildStatusBadge(
      context,
      PhosphorIconsRegular.checkCircle,
      'Up to date',
      Theme.of(context).colorScheme.primary,
      isSelected,
    );
  }

  /// Fetches this one repository with credential prompts allowed.
  ///
  /// The background sweep runs without them so it can never interrupt; here the
  /// user explicitly asked, so the helper's sign-in window is expected.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    await ref
        .read(workspaceRepositoryStatusProvider.notifier)
        .refreshStatus(repository, fetchRemote: true, allowPrompts: true);
  }

  Widget _buildStatusBadge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    bool isSelected,
  ) {
    return Container(
      // A hand-painted status pill is one of the micro-surfaces the census
      // sends to `surfaces.badge` whole: its inset is the badge member's own
      // geometry, not an `Inset` rung. `Inset` cannot state this pill's h8/v4
      // (both axes take the same rung), and resolving `tight` symmetrically
      // grew the pill 8 px taller inside a grid tile whose height
      // `childAspectRatio: 1.2` fixes - a Column that already had no slack.
      // The literal therefore stays with the drawing until the whole badge
      // moves onto its member, exactly like the fill, border and radius
      // beside it.
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: AppTheme.paddingXS,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const BaseGap(Proximity.hairline),
          // Deliberately still the old label: this helper's Color parameter
          // also paints the badge's fill, border and icon, so it can only
          // become a Tone when the whole badge moves onto `surfaces.badge` in
          // the surface sub-phase - the application cannot resolve a Tone to
          // a Color for its own decoration, and the seam is right to forbid
          // that.
          LabelMediumLabel(label, color: color),
        ],
      ),
    );
  }
}
