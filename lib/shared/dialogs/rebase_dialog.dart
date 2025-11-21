import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
        loading: () => [
          BaseButton(
            label: AppLocalizations.of(context)!.close,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        error: (_, _) => [
          BaseButton(
            label: AppLocalizations.of(context)!.close,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, RebaseState state) {
    if (state.isActive) {
      return [
        if (!state.hasConflicts) ...[
          BaseButton(
            label: AppLocalizations.of(context)!.abort,
            variant: ButtonVariant.tertiary,
            onPressed: _abortRebase,
          ),
        ],
        if (state.hasConflicts) ...[
          BaseButton(
            label: AppLocalizations.of(context)!.abort,
            variant: ButtonVariant.tertiary,
            onPressed: _abortRebase,
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.skip,
            variant: ButtonVariant.tertiary,
            onPressed: _skipRebase,
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.continueOperation,
            variant: ButtonVariant.primary,
            onPressed: _continueRebase,
          ),
        ],
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    } else {
      return [
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.startRebase,
          variant: ButtonVariant.primary,
          onPressed: (_selectedBranch != null && !_isRebasing) ? _startRebase : null,
        ),
      ];
    }
  }

  Widget _buildStart(BuildContext context, String? currentBranch) {
    final branchesAsync = ref.watch(allBranchesProvider);

    return branchesAsync.when(
      data: (branches) {
        // Filter out current branch
        final availableBranches = branches.where((b) => b.name != currentBranch).toList();

        if (availableBranches.isEmpty) {
          return Center(
            child: BodyLargeLabel(AppLocalizations.of(context)!.noNodesAvailable),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.info, size: 20),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(AppLocalizations.of(context)!.rebaseWillReplayCommits),
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
                borderRadius: BorderRadius.circular(8),
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
              subtitle: Text(AppLocalizations.of(context)!.editCommitsDuringRebase),
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
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(8),
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
                    child: BodySmallLabel(AppLocalizations.of(context)!.rebaseWarning),
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
            borderRadius: BorderRadius.circular(8),
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
                      state.hasConflicts ? AppLocalizations.of(context)!.rebaseConflicts : AppLocalizations.of(context)!.rebaseInProgress,
                    ),
                  ),
                ],
              ),
              if (state.progressText != null) ...[
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  AppLocalizations.of(context)!.step(state.progressText ?? '', 1, 1),
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
            borderRadius: BorderRadius.circular(4),
          ),
        if (state.progress != null) const SizedBox(height: AppTheme.paddingL),

        // Rebase info
        TitleSmallLabel(AppLocalizations.of(context)!.rebaseOntoBranch),
        const SizedBox(height: AppTheme.paddingS),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.gitBranch, size: 20),
              const SizedBox(width: AppTheme.paddingS),
              BodyMediumLabel(
                state.ontoBranch ?? 'Unknown',
              ),
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
              borderRadius: BorderRadius.circular(8),
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
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(8),
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
                BodySmallLabel(AppLocalizations.of(context)!.resolveConflictsInChangesScreen),
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

        const Spacer(),

        // Instructions
        if (!state.hasConflicts) ...[
          BodySmallLabel(AppLocalizations.of(context)!.rebaseIsInProgress),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel('• ${AppLocalizations.of(context)!.abortToCancelAndReturnToOriginalState}'),
          BodySmallLabel('• ${AppLocalizations.of(context)!.waitForRebaseToCompleteAutomatically}'),
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
          TitleLargeLabel(AppLocalizations.of(context)!.error(error.toString())),
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
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.rebaseBranch(
        ontoBranch: _selectedBranch!,
        interactive: _interactive,
      );

      // Refresh rebase state
      ref.invalidate(rebaseStateProvider);
      ref.invalidate(repositoryStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rebaseStartedSuccessfully),
            backgroundColor: AppTheme.gitAdded,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a conflict error
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('conflict') || errorMsg.contains('merge')) {
          ref.invalidate(rebaseStateProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.rebaseStartedConflictNeedsResolution),
              backgroundColor: AppTheme.gitModified,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToStartRebase(e.toString())),
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
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.continueRebase();

      // Refresh state
      ref.invalidate(rebaseStateProvider);
      ref.invalidate(repositoryStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rebaseContinued),
            backgroundColor: AppTheme.gitAdded,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToContinueRebase(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _skipRebase() async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.skipRebase();

      // Refresh state
      ref.invalidate(rebaseStateProvider);
      ref.invalidate(repositoryStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.commitSkipped),
            backgroundColor: AppTheme.gitModified,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSkip(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _abortRebase() async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.abortRebase();

      // Refresh state
      ref.invalidate(rebaseStateProvider);
      ref.invalidate(repositoryStatusProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rebaseAborted),
            backgroundColor: AppTheme.gitDeleted,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToAbortRebase(e.toString())),
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
