import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        DialogRouteSpec,
        IconRole,
        Inset,
        NoticeAction,
        NoticeSpec,
        Overlays,
        ProgressExtent,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../generated/app_localizations.dart';
import '../components/base_card.dart';
import '../components/base_progress.dart';
import '../components/base_toggle_row.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../../core/git/models/rebase_state.dart';
import '../../core/git/models/branch.dart';
import '../../core/navigation/navigation_item.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';

/// One standing statement about the whole dialog, drawn by the skin.
///
/// Every notice in this file used to be a hand-painted `Container`: a tonal
/// fill, a 12 dp corner, a 16 dp inset, a mark and a line of words. That is
/// `surfaces.banner` — *something about this whole surface needs saying* —
/// so the construction leaves whole and the corner leaves with it. What the
/// banner is painted in, how far its words sit from its edge, and whether it
/// is rounded at all are the skin's answers now; this dialog states only what
/// the notice MEANS and what it says.
Widget _banner(BuildContext context, BannerSpec spec) => SkinScope.render(
  context,
  (Skin skin, BuildContext inner) => skin.surfaces.banner(inner, spec),
);

/// Dialog for Git rebase operations
class RebaseDialog extends ConsumerStatefulWidget {
  const RebaseDialog({super.key});

  @override
  ConsumerState<RebaseDialog> createState() => _RebaseDialogState();
}

class _RebaseDialogState extends ConsumerState<RebaseDialog> {
  String? _selectedBranch;
  bool _interactive = false;
  bool _isRebasing = false;

  @override
  Widget build(BuildContext context) {
    final rebaseStateAsync = ref.watch(rebaseStateProvider);
    final currentBranchAsync = ref.watch(currentBranchProvider);

    return BaseDialog(
      icon: IconRole.gitBranch,
      title: AppLocalizations.of(context)!.rebaseBranch,
      // Idle: Enter starts the rebase once a target is chosen. Conflicts:
      // Enter continues (the labeled primary). Otherwise Enter is inert.
      onSubmit: rebaseStateAsync.when(
        data: (state) {
          if (!state.isActive) {
            return (_selectedBranch != null && !_isRebasing)
                ? _startRebase
                : null;
          }
          return state.hasConflicts ? _continueRebase : null;
        },
        loading: () => null,
        error: (_, _) => null,
      ),
      content: rebaseStateAsync.when(
        data: (state) {
          if (state.isActive) {
            return _buildActive(context, state);
          } else {
            return _buildStart(context, currentBranchAsync.value);
          }
        },
        loading: () => const BaseProgress.block(),
        error: (error, _) => _buildError(context, error),
      ),
      actions: rebaseStateAsync.when(
        data: (state) => _buildActions(context, state),
        loading: () => [_closeAction(context)],
        error: (_, _) => [_closeAction(context)],
      ),
    );
  }

  /// Leaving the dialog while the rebase itself stays where it is. Dismissive
  /// rather than affirmative: it neither continues nor abandons the rebase,
  /// it just stops looking at it.
  DialogAction _closeAction(BuildContext context) => DialogAction(
    label: AppLocalizations.of(context)!.close,
    role: DialogActionRole.dismissive,
    onPressed: () => Navigator.of(context).pop(),
  );

  List<DialogAction> _buildActions(BuildContext context, RebaseState state) {
    if (state.isActive) {
      return [
        // `git rebase --abort` ends the rebase by returning the branch to
        // where it started. Deliberately a peer and not destructive: the
        // repository's own catalogue of destructive git actions
        // (lib/core/git/destructive_action.dart) does not list an abort, and
        // a dialog must not claim a danger the catalogue denies.
        DialogAction(
          label: AppLocalizations.of(context)!.abort,
          role: DialogActionRole.neutral,
          onPressed: _abortRebase,
        ),
        if (state.hasConflicts) ...[
          // Skipping drops the conflicting commit; continuing is the way
          // forward the dialog is asking about, and the one Enter fires.
          DialogAction(
            label: AppLocalizations.of(context)!.skip,
            role: DialogActionRole.neutral,
            onPressed: _skipRebase,
          ),
          DialogAction(
            label: AppLocalizations.of(context)!.continueOperation,
            role: DialogActionRole.affirmative,
            onPressed: _continueRebase,
          ),
        ],
        _closeAction(context),
      ];
    }
    return [
      DialogAction(
        label: AppLocalizations.of(context)!.cancel,
        role: DialogActionRole.dismissive,
        onPressed: () => Navigator.of(context).pop(),
      ),
      DialogAction(
        label: AppLocalizations.of(context)!.startRebase,
        role: DialogActionRole.affirmative,
        enabled: _selectedBranch != null && !_isRebasing,
        onPressed: _startRebase,
      ),
    ];
  }

  Widget _buildStart(BuildContext context, String? currentBranch) {
    final branchesAsync = ref.watch(allBranchesProvider);

    return branchesAsync.when(
      data: (branches) {
        // Filter out current branch
        final availableBranches = branches
            .where((b) => b.name != currentBranch)
            .toList();

        if (availableBranches.isEmpty) {
          return Center(
            child: BaseLabel(
              AppLocalizations.of(context)!.noNodesAvailable,
              role: TextRole.body,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // What a rebase does to the branch, said once and standing until
            // the dialog closes: that is `surfaces.banner`. The fill, the
            // corner, the inset and the mark's pairing all leave with the
            // hand-painted container; what stays is the tone, and `info` is
            // the word for exactly this - worth knowing, nothing is wrong.
            _banner(
              context,
              BannerSpec(
                tone: Tone.info,
                icon: IconRole.info,
                title: AppLocalizations.of(context)!.rebaseWillReplayCommits,
              ),
            ),
            const BaseGap(Proximity.separate),

            // Current branch
            BaseLabel(
              AppLocalizations.of(context)!.currentBranch,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            // One branch, shown as its own surface: `surfaces.card` through
            // the façade. The tonal fill and the corner were this dialog
            // painting a container, and the `onPrimaryContainer` beside them
            // was the other half of that same decision - a fill and the
            // foreground it pairs with, both of which only a skin may choose.
            // The card publishes its own foreground, so the branch name says
            // nothing about colour and the mark takes the ordinary rung (20,
            // the size the raw glyph stated by hand).
            BaseCard(
              inset: Inset.normal,
              content: Row(
                children: [
                  const BaseIcon(IconRole.gitBranch),
                  const BaseGap(Proximity.related),
                  BaseLabel(currentBranch ?? 'Unknown', role: TextRole.body),
                ],
              ),
            ),
            const BaseGap(Proximity.separate),

            // Target branch selection
            BaseLabel(
              AppLocalizations.of(context)!.rebaseOntoBranch,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            _buildBranchDropdown(
              branches: availableBranches,
              selectedBranch: _selectedBranch,
              hint: AppLocalizations.of(context)!.selectTargetBranch,
              onChanged: (branch) {
                setState(() => _selectedBranch = branch);
              },
            ),
            const BaseGap(Proximity.separate),

            // Interactive option
            BaseToggleRow(
              label: AppLocalizations.of(context)!.interactiveRebase,
              description: AppLocalizations.of(
                context,
              )!.editCommitsDuringRebase,
              value: _interactive,
              onChanged: (value) {
                setState(() => _interactive = value ?? false);
              },
            ),
            const BaseGap(Proximity.grouped),

            // The warning the whole dialog carries, which is the same member
            // as the notice above it and differs only in what it means. The
            // 30 % wash of the error container was this dialog deciding how
            // loudly a danger is painted; the tone says the danger and the
            // skin decides how loud it is. `danger` rather than `warning`
            // because that is the word the mark already carried here.
            _banner(
              context,
              BannerSpec(
                tone: Tone.danger,
                icon: IconRole.warningCircle,
                title: AppLocalizations.of(context)!.rebaseWarning,
              ),
            ),
          ],
        );
      },
      loading: () => const BaseProgress.block(),
      error: (error, _) =>
          Center(child: BaseLabel('Error: $error', role: TextRole.body)),
    );
  }

  Widget _buildActive(BuildContext context, RebaseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the rebase stands, as one statement about the whole dialog:
        // a headline and, under it, the step it is on. `surfaces.banner` is
        // the member that draws exactly that pair, so the two tonal
        // containers this dialog chose between become one tone - `danger`
        // when the rebase has stopped on a conflict, `info` while it is
        // simply running - and the corner, the fill, the mark's pairing and
        // the step line's own type step all belong to the skin now.
        _banner(
          context,
          BannerSpec(
            tone: state.hasConflicts ? Tone.danger : Tone.info,
            icon: state.hasConflicts
                ? IconRole.warningCircle
                : IconRole.gitBranch,
            title: state.hasConflicts
                ? AppLocalizations.of(context)!.rebaseConflicts
                : AppLocalizations.of(context)!.rebaseInProgress,
            body: state.progressText == null
                ? null
                : AppLocalizations.of(context)!.step(state.progressText ?? ''),
          ),
        ),
        const BaseGap(Proximity.grouped),

        // How far along the rebase is. `controls.progress` owns the bar's
        // thickness and its ends, which is what the 8 dp height and the 4 dp
        // corner were deciding here; `inline` is the rung, because this is a
        // bar in a line of content rather than a whole region given over to
        // waiting (the rung that draws a centred ring).
        if (state.progress != null)
          SkinScope.render(
            context,
            (Skin skin, BuildContext inner) => skin.controls.progress(
              inner,
              fraction: state.progress,
              extent: ProgressExtent.inline,
            ),
          ),
        if (state.progress != null) const BaseGap(Proximity.separate),

        // Rebase info
        BaseLabel(
          AppLocalizations.of(context)!.rebaseOntoBranch,
          role: TextRole.sectionTitle,
        ),
        const BaseGap(Proximity.related),
        // The branch the rebase is replaying onto: one git object, shown as
        // its own surface. The 1 px divider-coloured outline and the corner
        // it was drawn at were this dialog imitating a surface; the card IS
        // one, and how it is edged is the skin's answer.
        BaseCard(
          inset: Inset.normal,
          content: Row(
            children: [
              // The mark that names the branch beside it, at the ordinary
              // size: the two are one line.
              const BaseIcon(IconRole.gitBranch),
              const BaseGap(Proximity.related),
              BaseLabel(state.ontoBranch ?? 'Unknown', role: TextRole.body),
            ],
          ),
        ),
        const BaseGap(Proximity.separate),

        // Current commit
        if (state.currentCommit != null) ...[
          BaseLabel(
            AppLocalizations.of(context)!.currentCommit,
            role: TextRole.sectionTitle,
          ),
          const BaseGap(Proximity.related),
          // The commit being replayed, on the same terms as the branch above:
          // one object, one card, no outline drawn by hand.
          BaseCard(
            inset: Inset.normal,
            content: BaseLabel(state.currentCommit!, role: TextRole.body),
          ),
          const BaseGap(Proximity.separate),
        ],

        // Conflicts message
        if (state.hasConflicts) ...[
          // The conflict, and the one thing to do about it, as one standing
          // statement: `surfaces.banner` carries a headline, an explanation
          // and the actions that answer it, which is precisely the three-part
          // column this dialog was building by hand. The button becomes the
          // banner's own action, so how prominently a notice's way out is
          // drawn - and where it sits - stops being decided here.
          _banner(
            context,
            BannerSpec(
              tone: Tone.danger,
              icon: IconRole.warningCircle,
              title: AppLocalizations.of(context)!.conflictsDetected,
              body: AppLocalizations.of(
                context,
              )!.resolveConflictsInChangesScreen,
              actions: <NoticeAction>[
                NoticeAction(
                  label: AppLocalizations.of(context)!.goToChanges,
                  // The label is the only description the application has for
                  // this action, and a notice may be drawn mark-only where
                  // there is no room for words.
                  tooltip: AppLocalizations.of(context)!.goToChanges,
                  icon: IconRole.fileCode,
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(navigationDestinationProvider.notifier).state =
                        AppDestination.changes;
                  },
                ),
              ],
            ),
          ),
        ],

        // A fixed gap, not a Spacer: BaseDialog scrolls its content, so the
        // Column has unbounded height and a flex child (Spacer builds an
        // Expanded) throws instead of spacing.
        const BaseGap(Proximity.separate),

        // Instructions
        if (!state.hasConflicts) ...[
          BaseLabel(
            AppLocalizations.of(context)!.rebaseIsInProgress,
            role: TextRole.detail,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            '• ${AppLocalizations.of(context)!.abortToCancelAndReturnToOriginalState}',
            role: TextRole.detail,
          ),
          BaseLabel(
            '• ${AppLocalizations.of(context)!.waitForRebaseToCompleteAutomatically}',
            role: TextRole.detail,
          ),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    // The facade's own error shape rather than a hand-built copy of it
    // (#430). This column was held back by exactly one fact - the facade
    // painted every hero in the supporting foreground - and the hero's tone
    // is that fact stated as a meaning (#431): `ErrorState` says
    // `Tone.danger`, so the mark stays the failure colour because the state
    // SAYS failure, not because this dialog picked a colour. The `64` and
    // the empty second line go to the member with it.
    return ErrorState(message: error.toString());
  }

  Widget _buildBranchDropdown({
    required List<GitBranch> branches,
    required String? selectedBranch,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return BaseDropdown<String>(
      initialValue: selectedBranch,
      hintText: hint,
      prefixIcon: IconRole.gitBranch,
      items: branches.map((branch) {
        return BaseDropdownItem<String>(
          value: branch.name,
          builder: (context) => Row(
            children: [
              // A dense mark inside a menu entry: the row is one line tall and
              // the mark is part of the line rather than something standing
              // beside it.
              BaseIcon(
                branch.isRemote ? IconRole.cloud : IconRole.gitBranch,
                scale: ControlScale.compact,
              ),
              const BaseGap(Proximity.related),
              Text(branch.name),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _startRebase() async {
    if (_selectedBranch == null) return;

    setState(() => _isRebasing = true);

    try {
      // The GitActions wrapper owns the refresh contract for the history
      // rewrite and throws on failure so the conflict handling in catch
      // actually runs.
      // confirmed-by: this dialog itself; choosing the branch and pressing
      // Start Rebase is the confirmation.
      await ref
          .read(gitActionsProvider)
          .rebaseBranch(
            ontoBranch: _selectedBranch!,
            interactive: _interactive,
          );

      if (mounted) {
        // Nine notices in this file borrowed three GIT tones as generic
        // greens, ambers and reds. A git tone says what a FILE's state in the
        // index is; none of them says "this worked", "check this" or "this
        // was thrown away". Each notice states its own meaning now, and the
        // skin picks the colours.
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.success,
            title: AppLocalizations.of(context)!.rebaseStartedSuccessfully,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a conflict error; the wrapper already refreshed the
        // rebase state before rethrowing, so no invalidation is needed here.
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('conflict') || errorMsg.contains('merge')) {
          // The rebase is running but did not go through: not a failure the
          // user can do nothing about, a state that needs their attention.
          Overlays.notify(
            context,
            NoticeSpec(
              tone: Tone.warning,
              title: AppLocalizations.of(
                context,
              )!.rebaseStartedConflictNeedsResolution,
            ),
          );
        } else {
          Overlays.notify(
            context,
            NoticeSpec(
              tone: Tone.danger,
              title: AppLocalizations.of(
                context,
              )!.failedToStartRebase(e.toString()),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRebasing = false);
      }
    }
  }

  Future<void> _continueRebase() async {
    try {
      // The GitActions wrapper refreshes rebase state, status, branches and
      // history: continuing can complete the rewrite.
      await ref.read(gitActionsProvider).continueRebase();

      if (mounted) {
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.success,
            title: AppLocalizations.of(context)!.rebaseContinued,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: AppLocalizations.of(
              context,
            )!.failedToContinueRebase(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _skipRebase() async {
    try {
      // The GitActions wrapper refreshes rebase state, status, branches and
      // history: skipping advances (and can complete) the rewrite.
      await ref.read(gitActionsProvider).skipRebase();

      if (mounted) {
        // A commit was passed over rather than applied: worth flagging, and
        // possibly not what the user meant to do.
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.warning,
            title: AppLocalizations.of(context)!.commitSkipped,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: AppLocalizations.of(context)!.failedToSkip(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _abortRebase() async {
    try {
      // The GitActions wrapper refreshes rebase state, status, branches and
      // history: aborting moves the branch tip back to where it was.
      await ref.read(gitActionsProvider).abortRebase();

      if (mounted) {
        Navigator.of(context).pop();
        // The rewrite was thrown away and the branch tip moved back, which
        // the site said with the git-DELETED red. `danger` is that meaning
        // without borrowing a word about a file.
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: AppLocalizations.of(context)!.rebaseAborted,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Overlays.notify(
          context,
          NoticeSpec(
            tone: Tone.danger,
            title: AppLocalizations.of(
              context,
            )!.failedToAbortRebase(e.toString()),
          ),
        );
      }
    }
  }
}

/// Show rebase dialog
Future<void> showRebaseDialog(BuildContext context) {
  return Overlays.dialogFrom(
    context,
    route: DialogRouteSpec(title: AppLocalizations.of(context)!.rebaseBranch),
    builder: (context) => const RebaseDialog(),
  );
}
