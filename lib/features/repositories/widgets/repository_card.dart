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
        PressableSpec,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
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
      // Both washes left with the card, exactly as this comment used to
      // predict: they were the card's own background, a fill is what a surface
      // is made of, and only a skin may resolve a meaning into one. What the
      // two of them were saying is `Tone.accent` - "this card is the one being
      // acted on" - and the member draws the primary wash for the single
      // selection and the secondary wash for a card gathered into a batch, so
      // the two selections stay tellable apart without this screen naming
      // either colour. A card carrying no selection states no identity, which
      // is what keeps its resting outline the neutral one.
      tone: (isSelected || isHighlighted || isMultiSelected)
          ? Tone.accent
          : Tone.neutral,
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
            // A setting the user has to supply before git will commit at all:
            // "this may not be what you intended", not a destruction.
            _buildStatusBadge(
              context,
              IconRole.gear,
              'Git not configured',
              BadgeVariant.warning,
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
                          IconRole.warningCircle,
                          'Broken',
                          BadgeVariant.danger,
                        ),
                      ),

                    // Commits behind (need to pull). Worth knowing and nothing
                    // is wrong, which is what `info` says; the arrow and the
                    // count are what tell it apart from the pill below, and
                    // they always were - Material answers `info` and `primary`
                    // with the same role, a collapse the contract records
                    // rather than hides (material_ink.dart:173-177).
                    if (status.hasIncoming)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          IconRole.arrowDown,
                          '↓${status.commitsBehind}',
                          BadgeVariant.info,
                        ),
                      ),

                    // Commits ahead (need to push)
                    if (status.hasOutgoing)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          IconRole.arrowUp,
                          '↑${status.commitsAhead}',
                          BadgeVariant.primary,
                        ),
                      ),

                    // Uncommitted changes. The pill stands for tracked files
                    // whose content differs from the index, which is the git
                    // palette's modified colour by definition rather than a
                    // scheme role picked for contrast.
                    if (status.hasUncommittedChanges)
                      ContentPort(
                        _buildStatusBadge(
                          context,
                          IconRole.pencilSimple,
                          'Changes',
                          BadgeVariant.warning,
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
              // NOT converted, and reported as a contract finding rather than
              // rounded onto the nearest member. The meaning is banner's -
              // "something about this whole surface needs saying" - but
              // `BannerSpec` carries no rung for how loudly, and Material's
              // answer to it is the shell's screen-wide warning strip: a
              // 16 dp inset around a 24 dp mark and a `titleMedium`
              // statement, ~56 dp tall. This note is a 32 dp strip inside a
              // grid tile whose height `childAspectRatio: 1.2` fixes, so the
              // member as specified cannot draw it. The fill and the corner
              // stay until `BannerSpec` can say "inline, inside a surface".
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
      // The pill is a control here and nowhere else on the card, so the press
      // target, its state layer and its tooltip are `surfaces.pressable` -
      // the member that exists precisely because a bare detector gives a tap
      // target with no state layer. The `InkWell`'s own corner went with it:
      // it existed only to round the ripple to the pill's radius, and neither
      // number is the application's any more.
      return SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.pressable(
          inner,
          PressableSpec(
            tooltip: 'This repository needs a sign-in. Click to authenticate.',
            onTap: () => _signIn(context, ref),
            child: ContentPort(
              _buildStatusBadge(
                context,
                IconRole.signIn,
                'Sign-in required',
                // Something is missing that the user must supply before the
                // check can run - a doubt to resolve, not a destruction.
                BadgeVariant.warning,
              ),
            ),
          ),
        );
      });
    }

    if (status.isRemoteUnreachable) {
      return Tooltip(
        message: 'The remote could not be reached. It will be retried.',
        child: _buildStatusBadge(
          context,
          IconRole.cloudSlash,
          'Unreachable',
          // No particular meaning: the check will be retried and nothing is
          // asked of the user, which is the neutral chip.
          BadgeVariant.neutral,
        ),
      );
    }

    if (status.remoteCheckFailedUnknown) {
      return Tooltip(
        message: 'The remote check failed. See the command log for details.',
        child: _buildStatusBadge(
          context,
          IconRole.warningCircle,
          'Check failed',
          BadgeVariant.danger,
        ),
      );
    }

    if (status.isRemoteUnchecked) {
      return Tooltip(
        message: 'Not compared against the remote yet.',
        child: _buildStatusBadge(
          context,
          IconRole.clockCountdown,
          'Not checked',
          BadgeVariant.neutral,
        ),
      );
    }

    return _buildStatusBadge(
      context,
      IconRole.checkCircle,
      'Up to date',
      // "This finished, and it finished well" is what a repository in sync
      // with its remote is saying, and it is the one pill on the card that
      // reports an outcome rather than an amount.
      BadgeVariant.success,
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

  /// One status pill, drawn by `surfaces.badge` through [BaseBadge].
  ///
  /// The whole micro-surface has left: the pill's fill, its 50 % edge, its
  /// corner, its h8/v4 inset, the 14 px mark and the `Color` that painted all
  /// four are the badge member's geometry now, and what the card states is
  /// only what each pill MEANS. That is what unblocks the `Color` parameter
  /// this helper used to carry — the note that stood here was right that a
  /// tone cannot be resolved into a `Color` for a hand-painted decoration, and
  /// wrong only about when: there is no decoration left to paint.
  ///
  /// **The pill is dense on purpose.** `BadgeSize.small` is `ControlScale`'s
  /// `compact` rung — "a chip, a row-level action" in the vocabulary's own
  /// words — and it is the rung this application's other row-level pill (the
  /// current-branch mark in the merge dialog) already draws at. It is smaller
  /// than the hand-painted copy in every direction (label 12 → 10, mark
  /// 14 → 10, vertical inset 4 → 2, horizontal inset unchanged at 8), so the
  /// wrap of badges can only get shorter inside a grid tile whose height
  /// `childAspectRatio: 1.2` fixes.
  ///
  /// **`isSelected` is gone from the signature, not dropped.** It selected
  /// between a 10 % and a 20 % wash of the badge's own colour, which was this
  /// card restating its selection on every pill inside it; the member paints
  /// one fill per tone, and the card's selection is already said once by the
  /// card.
  Widget _buildStatusBadge(
    BuildContext context,
    IconRole icon,
    String label,
    BadgeVariant variant,
  ) {
    return BaseBadge(
      label: label,
      icon: icon,
      variant: variant,
      size: BadgeSize.small,
    );
  }
}
