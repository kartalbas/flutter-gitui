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
import '../../core/git/models/bisect_state.dart';
import '../../core/git/models/commit.dart';

/// Dialog for Git bisect operations
class BisectDialog extends ConsumerStatefulWidget {
  const BisectDialog({super.key});

  @override
  ConsumerState<BisectDialog> createState() => _BisectDialogState();
}

class _BisectDialogState extends ConsumerState<BisectDialog> {
  String? _selectedGoodCommit;
  String? _selectedBadCommit;
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final bisectStateAsync = ref.watch(bisectStateProvider);

    return BaseDialog(
      icon: PhosphorIconsRegular.gitBranch,
      title: AppLocalizations.of(context)!.gitBisect,
      content: bisectStateAsync.when(
          data: (state) {
            if (state.isCompleted) {
              return _buildCompleted(context, state);
            } else if (state.isActive) {
              return _buildActive(context, state);
            } else {
              return _buildStart(context);
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(context, error),
        ),
      actions: bisectStateAsync.when(
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

  List<Widget> _buildActions(BuildContext context, BisectState state) {
    if (state.isCompleted) {
      return [
        BaseButton(
          label: AppLocalizations.of(context)!.reset,
          variant: ButtonVariant.tertiary,
          onPressed: _resetBisect,
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    } else if (state.isActive) {
      return [
        BaseButton(
          label: AppLocalizations.of(context)!.reset,
          variant: ButtonVariant.tertiary,
          onPressed: _resetBisect,
        ),
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
          label: AppLocalizations.of(context)!.startBisect,
          variant: ButtonVariant.primary,
          onPressed: (_selectedGoodCommit != null && _selectedBadCommit != null && !_isStarting)
              ? _startBisect
              : null,
        ),
      ];
    }
  }

  Widget _buildStart(BuildContext context) {
    final commitsAsync = ref.watch(commitHistoryProvider);

    return commitsAsync.when(
      data: (commits) {
        if (commits.isEmpty) {
          return Center(
            child: BodyLargeLabel(AppLocalizations.of(context)!.noCommitsAvailable),
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
                    child: BodySmallLabel(AppLocalizations.of(context)!.bisectHelpsFindCommitThatIntroducedBug),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Good commit selection
            TitleSmallLabel(AppLocalizations.of(context)!.goodCommitWhereBugWasNotPresent),
            const SizedBox(height: AppTheme.paddingS),
            _buildCommitDropdown(
              commits: commits,
              selectedCommit: _selectedGoodCommit,
              hint: AppLocalizations.of(context)!.selectAGoodCommit,
              onChanged: (hash) {
                setState(() => _selectedGoodCommit = hash);
              },
            ),
            const SizedBox(height: AppTheme.paddingM),

            // Bad commit selection
            TitleSmallLabel(AppLocalizations.of(context)!.badCommitWhereBugIsPresent),
            const SizedBox(height: AppTheme.paddingS),
            _buildCommitDropdown(
              commits: commits,
              selectedCommit: _selectedBadCommit,
              hint: AppLocalizations.of(context)!.selectABadCommitDefaultsToHead,
              onChanged: (hash) {
                setState(() => _selectedBadCommit = hash);
              },
              allowHead: true,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: BodyMediumLabel('Error: $error')),
    );
  }

  Widget _buildActive(BuildContext context, BisectState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.gitBranch, size: 20),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: TitleMediumLabel(AppLocalizations.of(context)!.bisectInProgress),
                  ),
                ],
              ),
              if (state.stepsRemaining != null) ...[
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  AppLocalizations.of(context)!.approximatelyStepsRemaining(state.stepsRemaining.toString(), state.stepsRemaining as Object),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.paddingL),

        // Current commit
        TitleMediumLabel(AppLocalizations.of(context)!.currentCommit),
        const SizedBox(height: AppTheme.paddingS),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: BodyMediumLabel(state.currentCommit ?? 'Unknown'),
        ),
        const SizedBox(height: AppTheme.paddingL),

        // Instructions
        TitleSmallLabel(AppLocalizations.of(context)!.testThisCommitAndMark),
        const SizedBox(height: AppTheme.paddingM),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.good,
                variant: ButtonVariant.success,
                leadingIcon: PhosphorIconsRegular.check,
                onPressed: () => _markCommit(BisectStep.good),
                fullWidth: true,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.bad,
                variant: ButtonVariant.danger,
                leadingIcon: PhosphorIconsRegular.x,
                onPressed: () => _markCommit(BisectStep.bad),
                fullWidth: true,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.skip,
                variant: ButtonVariant.secondary,
                leadingIcon: PhosphorIconsRegular.skipForward,
                onPressed: () => _markCommit(BisectStep.skip),
                fullWidth: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.paddingL),

        // History
        TitleSmallLabel(AppLocalizations.of(context)!.bisectHistory),
        const SizedBox(height: AppTheme.paddingS),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.goodCommits.isNotEmpty) ...[
                    BodyMediumLabel(
                      AppLocalizations.of(context)!.goodCommits(state.goodCommits.length),
                      color: AppTheme.gitAdded,
                    ),
                    ...state.goodCommits.map((hash) => BodySmallLabel('  $hash')),
                    const SizedBox(height: AppTheme.paddingS),
                  ],
                  if (state.badCommits.isNotEmpty) ...[
                    BodyMediumLabel(
                      AppLocalizations.of(context)!.badCommits(state.badCommits.length),
                      color: AppTheme.gitDeleted,
                    ),
                    ...state.badCommits.map((hash) => BodySmallLabel('  $hash')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleted(BuildContext context, BisectState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.checkCircle,
            size: 64,
            color: AppTheme.gitAdded,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.bisectComplete),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(AppLocalizations.of(context)!.foundFirstBadCommit),
          const SizedBox(height: AppTheme.paddingS),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: AppTheme.gitDeleted.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              state.foundCommit ?? 'Unknown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildCommitDropdown({
    required List<GitCommit> commits,
    required String? selectedCommit,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool allowHead = false,
  }) {
    return BaseDropdown<String>(
      initialValue: selectedCommit,
      hintText: hint,
      items: [
        if (allowHead)
          BaseDropdownItem<String>.simple(
            value: 'HEAD',
            label: AppLocalizations.of(context)!.headCurrentCommit,
          ),
        ...commits.take(50).map((commit) {
          return BaseDropdownItem<String>(
            value: commit.hash,
            builder: (context) => Text(
              '${commit.shortHash} - ${commit.message}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _startBisect() async {
    if (_selectedGoodCommit == null) return;

    setState(() => _isStarting = true);

    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.startBisect(
        goodCommit: _selectedGoodCommit!,
        badCommit: _selectedBadCommit ?? 'HEAD',
      );

      // Refresh bisect state
      ref.invalidate(bisectStateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.bisectStarted),
            backgroundColor: AppTheme.gitAdded,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToStartBisect(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _markCommit(BisectStep step) async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      switch (step) {
        case BisectStep.good:
          await gitService.markBisectGood();
          break;
        case BisectStep.bad:
          await gitService.markBisectBad();
          break;
        case BisectStep.skip:
          await gitService.skipBisect();
          break;
      }

      // Refresh bisect state
      ref.invalidate(bisectStateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.markedAs(step.displayName, step.displayName)),
            backgroundColor: AppTheme.gitAdded,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToMarkCommit(e.toString(), 'status')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _resetBisect() async {
    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      await gitService.resetBisect();

      // Refresh bisect state
      ref.invalidate(bisectStateProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.bisectReset),
            backgroundColor: AppTheme.gitAdded,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToResetBisect(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Show bisect dialog
Future<void> showBisectDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const BisectDialog(),
  );
}
