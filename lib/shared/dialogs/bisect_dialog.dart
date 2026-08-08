import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../../core/git/models/bisect_state.dart';
import '../../core/git/models/commit.dart';
import '../components/base_layout.dart';

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
      icon: IconRole.gitBranch,
      title: AppLocalizations.of(context)!.gitBisect,
      // While a bisect runs, Good/Bad/Skip are peers with no single primary,
      // so Enter stays inert in that state.
      onSubmit: bisectStateAsync.when(
        data: (state) {
          if (state.isCompleted) return () => Navigator.of(context).pop();
          if (state.isActive) return null;
          return (_selectedGoodCommit != null &&
                  _selectedBadCommit != null &&
                  !_isStarting)
              ? _startBisect
              : null;
        },
        loading: () => null,
        error: (_, _) => null,
      ),
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
        // Nothing is known about the bisect yet, so leaving is all this
        // dialog can offer and it is therefore what Enter would finish on.
        loading: () => [_closeAction(context, DialogActionRole.affirmative)],
        error: (_, _) => [_closeAction(context, DialogActionRole.affirmative)],
      ),
    );
  }

  DialogAction _closeAction(BuildContext context, DialogActionRole role) =>
      DialogAction(
        label: AppLocalizations.of(context)!.close,
        role: role,
        onPressed: () => Navigator.of(context).pop(),
      );

  /// `git bisect reset` returns the working tree to where the bisect started
  /// and leaves the dialog open, so it is a peer of closing rather than a
  /// second way to finish.
  DialogAction _resetAction(BuildContext context) => DialogAction(
    label: AppLocalizations.of(context)!.reset,
    role: DialogActionRole.neutral,
    onPressed: _resetBisect,
  );

  List<DialogAction> _buildActions(BuildContext context, BisectState state) {
    // Completed: the bisect has named the offending commit and there is
    // nothing left to answer, so acknowledging the result finishes the dialog
    // - which is also what onSubmit fires Enter into above.
    if (state.isCompleted) {
      return [
        _resetAction(context),
        _closeAction(context, DialogActionRole.affirmative),
      ];
    }
    // Running: Good, Bad and Skip live in the content area and are the real
    // answers; closing abandons the question rather than answering it.
    if (state.isActive) {
      return [
        _resetAction(context),
        _closeAction(context, DialogActionRole.dismissive),
      ];
    }
    return [
      DialogAction(
        label: AppLocalizations.of(context)!.cancel,
        role: DialogActionRole.dismissive,
        onPressed: () => Navigator.of(context).pop(),
      ),
      DialogAction(
        label: AppLocalizations.of(context)!.startBisect,
        role: DialogActionRole.affirmative,
        enabled:
            _selectedGoodCommit != null &&
            _selectedBadCommit != null &&
            !_isStarting,
        onPressed: _startBisect,
      ),
    ];
  }

  Widget _buildStart(BuildContext context) {
    final commitsAsync = ref.watch(commitHistoryProvider);

    return commitsAsync.when(
      data: (commits) {
        if (commits.isEmpty) {
          return Center(
            child: BaseLabel(
              AppLocalizations.of(context)!.noCommitsAvailable,
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
                        AppLocalizations.of(
                          context,
                        )!.bisectHelpsFindCommitThatIntroducedBug,
                        role: TextRole.detail,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BaseGap(Proximity.separate),

            // Good commit selection
            BaseLabel(
              AppLocalizations.of(context)!.goodCommitWhereBugWasNotPresent,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            _buildCommitDropdown(
              commits: commits,
              selectedCommit: _selectedGoodCommit,
              hint: AppLocalizations.of(context)!.selectAGoodCommit,
              onChanged: (hash) {
                setState(() => _selectedGoodCommit = hash);
              },
            ),
            const BaseGap(Proximity.grouped),

            // Bad commit selection
            BaseLabel(
              AppLocalizations.of(context)!.badCommitWhereBugIsPresent,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            _buildCommitDropdown(
              commits: commits,
              selectedCommit: _selectedBadCommit,
              hint: AppLocalizations.of(
                context,
              )!.selectABadCommitDefaultsToHead,
              onChanged: (hash) {
                setState(() => _selectedBadCommit = hash);
              },
              allowHead: true,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: BaseLabel('Error: $error', role: TextRole.body)),
    );
  }

  Widget _buildActive(BuildContext context, BisectState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status banner
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
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
                    const BaseIcon(IconRole.gitBranch),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.bisectInProgress,
                        role: TextRole.sectionTitle,
                      ),
                    ),
                  ],
                ),
                if (state.stepsRemaining != null) ...[
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(context)!.approximatelyStepsRemaining(
                      state.stepsRemaining.toString(),
                      state.stepsRemaining as Object,
                    ),
                    role: TextRole.body,
                  ),
                ],
              ],
            ),
          ),
        ),
        const BaseGap(Proximity.separate),

        // Current commit
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
            child: BaseLabel(
              state.currentCommit ?? 'Unknown',
              role: TextRole.body,
            ),
          ),
        ),
        const BaseGap(Proximity.separate),

        // Instructions
        BaseLabel(
          AppLocalizations.of(context)!.testThisCommitAndMark,
          role: TextRole.sectionTitle,
        ),
        const BaseGap(Proximity.grouped),

        // Action buttons. The gaps inside the run say `grouped`: sibling
        // actions are members of one group, the vocabulary's own exemplar
        // for a run of actions.
        Row(
          children: [
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.good,
                variant: ButtonVariant.success,
                leadingIcon: IconRole.check,
                onPressed: () => _markCommit(BisectStep.good),
                fullWidth: true,
              ),
            ),
            const BaseGap(Proximity.grouped),
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.bad,
                variant: ButtonVariant.danger,
                leadingIcon: IconRole.x,
                onPressed: () => _markCommit(BisectStep.bad),
                fullWidth: true,
              ),
            ),
            const BaseGap(Proximity.grouped),
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.skip,
                variant: ButtonVariant.secondary,
                leadingIcon: IconRole.skipForward,
                onPressed: () => _markCommit(BisectStep.skip),
                fullWidth: true,
              ),
            ),
          ],
        ),
        const BaseGap(Proximity.separate),

        // History needs a bounded height: BaseDialog wraps the content in a
        // SingleChildScrollView, so a flex child would sit in an unbounded
        // Column and throw. The cap keeps the secondary list compact; its own
        // scroll view handles longer histories.
        BaseLabel(
          AppLocalizations.of(context)!.bisectHistory,
          role: TextRole.sectionTitle,
        ),
        const BaseGap(Proximity.related),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.goodCommits.isNotEmpty) ...[
                      BaseLabel(
                        AppLocalizations.of(
                          context,
                        )!.goodCommits(state.goodCommits.length),
                        role: TextRole.body,
                        tone: Tone.gitAdded,
                      ),
                      ...state.goodCommits.map(
                        (hash) => BaseLabel('  $hash', role: TextRole.detail),
                      ),
                      const BaseGap(Proximity.related),
                    ],
                    if (state.badCommits.isNotEmpty) ...[
                      BaseLabel(
                        AppLocalizations.of(
                          context,
                        )!.badCommits(state.badCommits.length),
                        role: TextRole.body,
                        tone: Tone.gitDeleted,
                      ),
                      ...state.badCommits.map(
                        (hash) => BaseLabel('  $hash', role: TextRole.detail),
                      ),
                    ],
                  ],
                ),
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
            color: context.gitColors.added,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.bisectComplete,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.grouped),
          BaseLabel(
            AppLocalizations.of(context)!.foundFirstBadCommit,
            role: TextRole.body,
          ),
          const BaseGap(Proximity.related),
          Container(
            decoration: BoxDecoration(
              color: context.gitColors.deleted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            // Still a hand-set style, and the blocker is `FontWeight.bold`:
            // the hash this bisect found is the result the whole dialog exists
            // to report, and `BaseLabel(TextRole.code)` carries no weight, so
            // converting would silently drop the stroke that makes it the
            // answer rather than another line of output. Dropping a weight
            // inside a rename is the mistake the staged-state checkboxes
            // already made once. The scheme's `onSurface` beside it is
            // stranded with the style rather than independently convertible: a
            // `Tone` reaches text only through `BaseLabel`, which is the widget
            // the weight rules out.
            child: BaseInset(
              child: SelectableText(
                state.foundCommit ?? 'Unknown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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
            backgroundColor: context.gitColors.added,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToStartBisect(e.toString()),
            ),
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
            content: Text(
              AppLocalizations.of(
                context,
              )!.markedAs(step.displayName, step.displayName),
            ),
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
              )!.failedToMarkCommit(e.toString(), 'status'),
            ),
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
            backgroundColor: context.gitColors.added,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToResetBisect(e.toString()),
            ),
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
