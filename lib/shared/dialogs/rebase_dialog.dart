import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../../core/git/models/rebase_state.dart';
import '../../core/git/models/branch.dart';
import '../../core/navigation/navigation_item.dart';
import '../components/base_layout.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
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
            // Info banner
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  children: [
                    // The mark of an ordinary notice, at the ordinary size: it
                    // belongs to the line beside it rather than standing over
                    // it.
                    const BaseIcon(IconRole.info),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.rebaseWillReplayCommits,
                        role: TextRole.detail,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BaseGap(Proximity.separate),

            // Current branch
            BaseLabel(
              AppLocalizations.of(context)!.currentBranch,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.gitBranch,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const BaseGap(Proximity.related),
                    // The panel behind this line is `primaryContainer`; naming
                    // its paired foreground is the container's business, so the
                    // name of the branch says nothing about colour.
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      child: BaseLabel(
                        currentBranch ?? 'Unknown',
                        role: TextRole.body,
                      ),
                    ),
                  ],
                ),
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
            CheckboxListTile(
              title: Text(AppLocalizations.of(context)!.interactiveRebase),
              subtitle: Text(
                AppLocalizations.of(context)!.editCommitsDuringRebase,
              ),
              value: _interactive,
              onChanged: (value) {
                setState(() => _interactive = value ?? false);
              },
            ),
            const BaseGap(Proximity.grouped),

            // Warning
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The mark of the warning this panel carries, at the
                    // ordinary size: Material's `error` role was its answer to
                    // a danger the panel around it has already named, and the
                    // 20 the mark stated is exactly what the ordinary rung
                    // renders, so the mark says the meaning now and the size
                    // stops being a decision this dialog makes.
                    const BaseIcon(IconRole.warningCircle, tone: Tone.danger),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.rebaseWarning,
                        role: TextRole.detail,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: BaseLabel('Error: $error', role: TextRole.body)),
    );
  }

  Widget _buildActive(BuildContext context, RebaseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status banner
        Container(
          decoration: BoxDecoration(
            color: state.hasConflicts
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: BaseInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // The mark of the status banner's headline, at the ordinary
                    // size: it belongs to the line beside it. It names no
                    // colour, so it keeps taking the one the banner around it
                    // publishes.
                    BaseIcon(
                      state.hasConflicts
                          ? IconRole.warningCircle
                          : IconRole.gitBranch,
                    ),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        state.hasConflicts
                            ? AppLocalizations.of(context)!.rebaseConflicts
                            : AppLocalizations.of(context)!.rebaseInProgress,
                        role: TextRole.sectionTitle,
                      ),
                    ),
                  ],
                ),
                if (state.progressText != null) ...[
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(
                      context,
                    )!.step(state.progressText ?? ''),
                    role: TextRole.body,
                  ),
                ],
              ],
            ),
          ),
        ),
        const BaseGap(Proximity.grouped),

        // Progress bar
        if (state.progress != null)
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
        if (state.progress != null) const BaseGap(Proximity.separate),

        // Rebase info
        BaseLabel(
          AppLocalizations.of(context)!.rebaseOntoBranch,
          role: TextRole.sectionTitle,
        ),
        const BaseGap(Proximity.related),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: BaseInset(
            child: Row(
              children: [
                // The mark that names the branch beside it, at the ordinary
                // size: the two are one line.
                const BaseIcon(IconRole.gitBranch),
                const BaseGap(Proximity.related),
                BaseLabel(state.ontoBranch ?? 'Unknown', role: TextRole.body),
              ],
            ),
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              child: BaseLabel(state.currentCommit!, role: TextRole.body),
            ),
          ),
          const BaseGap(Proximity.separate),
        ],

        // Conflicts message
        if (state.hasConflicts) ...[
          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Same mark, same meaning and the same rung as the
                      // warning above: the conflict this panel reports is the
                      // danger Material's `error` role was its answer to, and
                      // 20 is what the ordinary rung already renders.
                      const BaseIcon(IconRole.warningCircle, tone: Tone.danger),
                      const BaseGap(Proximity.related),
                      BaseLabel(
                        AppLocalizations.of(context)!.conflictsDetected,
                        role: TextRole.body,
                      ),
                    ],
                  ),
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(
                      context,
                    )!.resolveConflictsInChangesScreen,
                    role: TextRole.detail,
                  ),
                  const BaseGap(Proximity.grouped),
                  BaseButton(
                    label: AppLocalizations.of(context)!.goToChanges,
                    variant: ButtonVariant.primary,
                    leadingIcon: IconRole.fileCode,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(navigationDestinationProvider.notifier).state =
                          AppDestination.changes;
                    },
                  ),
                ],
              ),
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
    // Shaped exactly like the empty-state facade takes - hero, headline,
    // sentence - and still not converted, because the blocker is the mark's
    // COLOUR rather than its size (#430). `EmptyStateWidget` paints its hero
    // in the supporting foreground unconditionally and carries no tone slot,
    // so adopting it here would turn a red failure mark grey, which is a
    // change of appearance rather than a rename. The `64` is stranded with the
    // colour: the two are one decision and cannot be half-converted.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.error(error.toString()),
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel('', role: TextRole.detail, align: TextAlign.center),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.rebaseStartedSuccessfully,
            ),
            backgroundColor: context.gitColors.added,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a conflict error; the wrapper already refreshed the
        // rebase state before rethrowing, so no invalidation is needed here.
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('conflict') || errorMsg.contains('merge')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.rebaseStartedConflictNeedsResolution,
              ),
              backgroundColor: context.gitColors.modified,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.failedToStartRebase(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rebaseContinued),
            backgroundColor: context.gitColors.added,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToContinueRebase(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.commitSkipped),
            backgroundColor: context.gitColors.modified,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSkip(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rebaseAborted),
            backgroundColor: context.gitColors.deleted,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToAbortRebase(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Show rebase dialog
Future<void> showRebaseDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const RebaseDialog(),
  );
}
