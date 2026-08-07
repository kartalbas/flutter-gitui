import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../../core/git/models/rebase_state.dart';
import '../../core/git/models/branch.dart';
import '../../core/navigation/navigation_item.dart';

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
      icon: PhosphorIconsRegular.gitBranch,
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
            child: BodyLargeLabel(
              AppLocalizations.of(context)!.noNodesAvailable,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.info, size: 20),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      AppLocalizations.of(context)!.rebaseWillReplayCommits,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Current branch
            TitleSmallLabel(AppLocalizations.of(context)!.currentBranch),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.gitBranch,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BodyMediumLabel(
                    currentBranch ?? 'Unknown',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Target branch selection
            TitleSmallLabel(AppLocalizations.of(context)!.rebaseOntoBranch),
            const SizedBox(height: AppTheme.paddingS),
            _buildBranchDropdown(
              branches: availableBranches,
              selectedBranch: _selectedBranch,
              hint: AppLocalizations.of(context)!.selectTargetBranch,
              onChanged: (branch) {
                setState(() => _selectedBranch = branch);
              },
            ),
            const SizedBox(height: AppTheme.paddingL),

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
            const SizedBox(height: AppTheme.paddingM),

            // Warning
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      AppLocalizations.of(context)!.rebaseWarning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: BodyMediumLabel('Error: $error')),
    );
  }

  Widget _buildActive(BuildContext context, RebaseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color: state.hasConflicts
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.hasConflicts
                        ? PhosphorIconsRegular.warningCircle
                        : PhosphorIconsRegular.gitBranch,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: TitleMediumLabel(
                      state.hasConflicts
                          ? AppLocalizations.of(context)!.rebaseConflicts
                          : AppLocalizations.of(context)!.rebaseInProgress,
                    ),
                  ),
                ],
              ),
              if (state.progressText != null) ...[
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  AppLocalizations.of(context)!.step(state.progressText ?? ''),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.paddingM),

        // Progress bar
        if (state.progress != null)
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
        if (state.progress != null) const SizedBox(height: AppTheme.paddingL),

        // Rebase info
        TitleSmallLabel(AppLocalizations.of(context)!.rebaseOntoBranch),
        const SizedBox(height: AppTheme.paddingS),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.gitBranch, size: 20),
              const SizedBox(width: AppTheme.paddingS),
              BodyMediumLabel(state.ontoBranch ?? 'Unknown'),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.paddingL),

        // Current commit
        if (state.currentCommit != null) ...[
          TitleSmallLabel(AppLocalizations.of(context)!.currentCommit),
          const SizedBox(height: AppTheme.paddingS),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BodyMediumLabel(state.currentCommit!),
          ),
          const SizedBox(height: AppTheme.paddingL),
        ],

        // Conflicts message
        if (state.hasConflicts) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    BodyMediumLabel(
                      AppLocalizations.of(context)!.conflictsDetected,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.paddingS),
                BodySmallLabel(
                  AppLocalizations.of(context)!.resolveConflictsInChangesScreen,
                ),
                const SizedBox(height: AppTheme.paddingM),
                BaseButton(
                  label: AppLocalizations.of(context)!.goToChanges,
                  variant: ButtonVariant.primary,
                  leadingIcon: PhosphorIconsRegular.fileCode,
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
        const SizedBox(height: AppTheme.paddingL),

        // Instructions
        if (!state.hasConflicts) ...[
          BodySmallLabel(AppLocalizations.of(context)!.rebaseIsInProgress),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            '• ${AppLocalizations.of(context)!.abortToCancelAndReturnToOriginalState}',
          ),
          BodySmallLabel(
            '• ${AppLocalizations.of(context)!.waitForRebaseToCompleteAutomatically}',
          ),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(
            AppLocalizations.of(context)!.error(error.toString()),
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel('', textAlign: TextAlign.center),
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
      prefixIcon: PhosphorIconsRegular.gitBranch,
      items: branches.map((branch) {
        return BaseDropdownItem<String>(
          value: branch.name,
          builder: (context) => Row(
            children: [
              if (branch.isRemote)
                const Icon(PhosphorIconsRegular.cloud, size: 16)
              else
                const Icon(PhosphorIconsRegular.gitBranch, size: 16),
              const SizedBox(width: AppTheme.paddingS),
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
