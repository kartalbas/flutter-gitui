import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ChoiceGroupSpec,
        ChoiceOption,
        ControlScale,
        IconRole,
        NoticeAction,
        NoticeSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../generated/app_localizations.dart';
import '../components/base_badge.dart';
import '../components/base_label.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../components/base_layout.dart';
import '../components/base_icon.dart';

/// One standing statement about the whole dialog, drawn by the skin.
///
/// Four notices in this file were four copies of one hand-painted container -
/// a tonal fill, a 12 dp corner, a 16 dp inset, sometimes a mark, sometimes a
/// second line. That construction is `surfaces.banner`: *something about this
/// whole surface needs saying*. It leaves whole, and the corner leaves with
/// it; the tone is the half of the decision that stays here.
Widget _banner(BuildContext context, BannerSpec spec) => SkinScope.render(
  context,
  (Skin skin, BuildContext inner) => skin.surfaces.banner(inner, spec),
);

/// Dialog for merging two branches (select both source and target)
class MergeBranchesDialog extends ConsumerStatefulWidget {
  const MergeBranchesDialog({super.key});

  @override
  ConsumerState<MergeBranchesDialog> createState() =>
      _MergeBranchesDialogState();
}

enum MergeStrategy { merge, rebase }

class _MergeBranchesDialogState extends ConsumerState<MergeBranchesDialog> {
  final _messageController = TextEditingController();

  GitBranch? _sourceBranch;
  GitBranch? _targetBranch;
  bool _isMerging = false;
  MergeStrategy _strategy = MergeStrategy.merge;
  bool _showRemoteBranchesForSource = false;
  bool _showRemoteBranchesForTarget = false;
  bool _pushAfterMerge = true; // Default to true for remote targets
  bool _initialized = false;

  // Merge options
  bool _noFastForward = false;
  bool _fastForwardOnly = false;
  bool _squash = false;

  // Rebase options
  bool _interactive = false;
  bool _preserveMerges = false;

  bool _customMessage = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(allBranchesProvider);
    final currentBranch = ref.watch(currentBranchProvider).value;

    return BaseDialog(
      icon: IconRole.gitMerge,
      title: AppLocalizations.of(context)!.mergeBranches,
      // Enter merges once both branches are chosen; Esc cancels.
      onSubmit: _isMerging || _sourceBranch == null || _targetBranch == null
          ? null
          : _mergeBranches,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BaseLabel(
              AppLocalizations.of(context)!.selectSourceAndTargetBranches,
              role: TextRole.body,
            ),
            const BaseGap(Proximity.separate),

            // Branch selection
            branchesAsync.when(
              data: (branches) {
                // Filter branches separately for source and target
                // Source: can be local or remote (you can merge FROM remote)
                final filteredSourceBranches = _showRemoteBranchesForSource
                    ? branches
                    : branches.where((b) => !b.isRemote).toList();

                // Target: can be local or remote (with special workflow for remote)
                final filteredTargetBranches = _showRemoteBranchesForTarget
                    ? branches
                    : branches.where((b) => !b.isRemote).toList();

                if (filteredSourceBranches.isEmpty &&
                    filteredTargetBranches.isEmpty) {
                  // Nothing to pick, and saying so replaces both pickers: a
                  // statement about the whole dialog rather than a control.
                  // It carries no mark, exactly as it did before.
                  return _banner(
                    context,
                    BannerSpec(
                      tone: Tone.info,
                      title: AppLocalizations.of(
                        context,
                      )!.noOtherBranchesAvailable,
                    ),
                  );
                }

                // Initialize source branch to current branch on first load
                if (!_initialized &&
                    currentBranch != null &&
                    filteredSourceBranches.isNotEmpty) {
                  _sourceBranch = filteredSourceBranches.firstWhere(
                    (b) => b.name == currentBranch,
                    orElse: () => filteredSourceBranches.first,
                  );
                  _initialized = true;
                  // Trigger rebuild after initialization
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                }

                final availableTargetBranches = _sourceBranch != null
                    ? filteredTargetBranches
                          .where((b) => b.name != _sourceBranch!.name)
                          .toList()
                    : filteredTargetBranches;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Source branch with toggle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BaseDropdown<GitBranch>(
                            initialValue: _sourceBranch,
                            autofocus: true,
                            labelText: AppLocalizations.of(
                              context,
                            )!.sourceBranch,
                            hintText: AppLocalizations.of(
                              context,
                            )!.selectSourceBranch,
                            prefixIcon: IconRole.gitBranch,
                            items: filteredSourceBranches.map((branch) {
                              return BaseDropdownItem(
                                value: branch,
                                builder: (context) => Row(
                                  children: [
                                    // A dense mark inside a menu entry: the row
                                    // is one line tall and the mark is part of
                                    // the line. The literal it used to state
                                    // sits on no icon scale at all, and every
                                    // other inline mark in this dialog already
                                    // says the dense rung.
                                    BaseIcon(
                                      branch.isRemote
                                          ? IconRole.cloud
                                          : IconRole.gitBranch,
                                      scale: ControlScale.compact,
                                    ),
                                    const BaseGap(Proximity.related),
                                    // A menu entry is one line tall; a long
                                    // branch name states its cap here and the
                                    // skin decides how the line ends.
                                    Expanded(
                                      child: BaseLabel(
                                        branch.name,
                                        role: TextRole.control,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (branch.name == currentBranch) ...[
                                      const BaseGap(Proximity.related),
                                      _currentBadge(context),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _isMerging
                                ? null
                                : (value) {
                                    setState(() {
                                      _sourceBranch = value;
                                      // Clear target if it's the same as source
                                      if (_targetBranch?.name == value?.name) {
                                        _targetBranch = null;
                                      }
                                    });
                                  },
                          ),
                        ),
                        const BaseGap(Proximity.grouped),
                        // Which branches the source picker offers.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const BaseGap(Proximity.related),
                            _branchScopeChoice(
                              context,
                              label: AppLocalizations.of(context)!.sourceBranch,
                              showRemote: _showRemoteBranchesForSource,
                              onChanged: (bool remote) {
                                setState(() {
                                  _showRemoteBranchesForSource = remote;
                                  _sourceBranch = null;
                                  _initialized = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const BaseGap(Proximity.grouped),

                    // Target branch with toggle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BaseDropdown<GitBranch>(
                            initialValue: _targetBranch,
                            labelText: AppLocalizations.of(
                              context,
                            )!.targetBranch,
                            hintText: AppLocalizations.of(
                              context,
                            )!.selectTargetBranch,
                            prefixIcon: IconRole.gitBranch,
                            items: availableTargetBranches.map((branch) {
                              return BaseDropdownItem(
                                value: branch,
                                builder: (context) => Row(
                                  children: [
                                    // The same dense mark as the source
                                    // picker's entries, said the same way.
                                    BaseIcon(
                                      branch.isRemote
                                          ? IconRole.cloud
                                          : IconRole.gitBranch,
                                      scale: ControlScale.compact,
                                    ),
                                    const BaseGap(Proximity.related),
                                    // A menu entry is one line tall; a long
                                    // branch name states its cap here and the
                                    // skin decides how the line ends.
                                    Expanded(
                                      child: BaseLabel(
                                        branch.name,
                                        role: TextRole.control,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (branch.name == currentBranch) ...[
                                      const BaseGap(Proximity.related),
                                      _currentBadge(context),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _isMerging || _sourceBranch == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _targetBranch = value;
                                    });
                                  },
                          ),
                        ),
                        const BaseGap(Proximity.grouped),
                        // Which branches the target picker offers.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const BaseGap(Proximity.related),
                            _branchScopeChoice(
                              context,
                              label: AppLocalizations.of(context)!.targetBranch,
                              showRemote: _showRemoteBranchesForTarget,
                              onChanged: (bool remote) {
                                setState(() {
                                  _showRemoteBranchesForTarget = remote;
                                  _targetBranch = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Show info message when remote target is selected
                    if (_targetBranch?.isRemote == true) ...[
                      const BaseGap(Proximity.grouped),
                      // What merging into a remote branch will actually do,
                      // as one standing statement: a headline and the steps
                      // under it, which is exactly the pair `surfaces.banner`
                      // draws. The 30 % washes of the container AND of the
                      // border were this dialog deciding how loud an
                      // informational notice is, and the `onPrimaryContainer`
                      // it published by hand was the other half of that same
                      // decision - all three leave with the surface, and one
                      // `Tone.info` says what is left.
                      _banner(
                        context,
                        BannerSpec(
                          tone: Tone.info,
                          icon: IconRole.info,
                          title: 'Merging to remote branch',
                          body:
                              'This will perform the following steps:\n'
                              '1. Fetch latest changes from remote\n'
                              '2. Create/update local tracking branch\n'
                              '3. Merge ${_sourceBranch?.name ?? 'source'} into local branch\n'
                              '4. ${_pushAfterMerge ? 'Push changes to remote' : 'Keep changes local (you can push later)'}',
                        ),
                      ),
                      // The choice the notice is about stays a control and
                      // therefore stays outside it: `BannerSpec` carries
                      // ACTIONS (things that happen when pressed) and has no
                      // slot for a setting the notice describes. Reported as
                      // a contract finding; placed directly under the banner
                      // so the two still read as one statement.
                      CheckboxListTile(
                        value: _pushAfterMerge,
                        onChanged: _isMerging
                            ? null
                            : (value) {
                                setState(() {
                                  _pushAfterMerge = value ?? true;
                                });
                              },
                        title: BaseLabel(
                          'Push to remote after merge',
                          role: TextRole.body,
                        ),
                        subtitle: BaseLabel(
                          _pushAfterMerge
                              ? 'Changes will be immediately visible on remote'
                              : 'You can review and push manually later',
                          role: TextRole.detail,
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => BaseLabel(
                AppLocalizations.of(
                  context,
                )!.errorLoadingBranches(error.toString()),
                role: TextRole.body,
                tone: Tone.danger,
              ),
            ),
            const BaseGap(Proximity.separate),

            // Strategy selector
            BaseLabel(
              AppLocalizations.of(context)!.strategy,
              role: TextRole.sectionTitle,
            ),
            const BaseGap(Proximity.related),
            SegmentedButton<MergeStrategy>(
              segments: [
                ButtonSegment(
                  value: MergeStrategy.merge,
                  label: Text(AppLocalizations.of(context)!.merge),
                  // A 16 px mark spelled as a PADDING token: the spacing
                  // vocabulary leaking into the icon one. What it says is that
                  // a segment's mark is dense, which is ControlScale.compact.
                  icon: const BaseIcon(
                    IconRole.gitMerge,
                    scale: ControlScale.compact,
                  ),
                ),
                ButtonSegment(
                  value: MergeStrategy.rebase,
                  label: Text(AppLocalizations.of(context)!.rebase),
                  icon: const BaseIcon(
                    IconRole.gitBranch,
                    scale: ControlScale.compact,
                  ),
                ),
              ],
              selected: {_strategy},
              onSelectionChanged: _isMerging
                  ? null
                  : (Set<MergeStrategy> newSelection) {
                      setState(() {
                        _strategy = newSelection.first;
                      });
                    },
            ),
            const BaseGap(Proximity.separate),

            // Merge/Rebase options (conditional based on strategy)
            if (_strategy == MergeStrategy.merge) ...[
              BaseLabel(
                AppLocalizations.of(context)!.mergeOptions,
                role: TextRole.sectionTitle,
              ),
              const BaseGap(Proximity.related),

              // Fast-forward only
              CheckboxListTile(
                value: _fastForwardOnly,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _fastForwardOnly = value ?? false;
                          if (_fastForwardOnly) {
                            _noFastForward = false;
                          }
                        });
                      },
                title: Text(AppLocalizations.of(context)!.fastForwardOnly),
                subtitle: Text(
                  AppLocalizations.of(context)!.abortIfFastForwardNotPossible,
                ),
                contentPadding: EdgeInsets.zero,
              ),

              // No fast-forward
              CheckboxListTile(
                value: _noFastForward,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _noFastForward = value ?? false;
                          if (_noFastForward) {
                            _fastForwardOnly = false;
                          }
                        });
                      },
                title: Text(AppLocalizations.of(context)!.noFastForward),
                subtitle: Text(
                  AppLocalizations.of(context)!.alwaysCreateMergeCommit,
                ),
                contentPadding: EdgeInsets.zero,
              ),

              // Squash
              CheckboxListTile(
                value: _squash,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _squash = value ?? false;
                        });
                      },
                title: Text(AppLocalizations.of(context)!.squashCommits),
                subtitle: Text(
                  AppLocalizations.of(
                    context,
                  )!.combineAllCommitsIntoSingleCommit,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ] else if (_strategy == MergeStrategy.rebase) ...[
              BaseLabel(
                AppLocalizations.of(context)!.rebaseOptions,
                role: TextRole.sectionTitle,
              ),
              const BaseGap(Proximity.related),

              // Interactive rebase
              CheckboxListTile(
                value: _interactive,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _interactive = value ?? false;
                        });
                      },
                title: Text(AppLocalizations.of(context)!.interactiveRebase),
                subtitle: Text(
                  AppLocalizations.of(context)!.interactiveRebaseDescription,
                ),
                contentPadding: EdgeInsets.zero,
              ),

              // Preserve merges
              CheckboxListTile(
                value: _preserveMerges,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _preserveMerges = value ?? false;
                        });
                      },
                title: Text(AppLocalizations.of(context)!.preserveMerges),
                subtitle: Text(
                  AppLocalizations.of(context)!.preserveMergesDescription,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],

            const BaseGap(Proximity.grouped),

            // Custom message option (only for merge, not rebase)
            if (_strategy == MergeStrategy.merge)
              CheckboxListTile(
                value: _customMessage,
                onChanged: _isMerging
                    ? null
                    : (value) {
                        setState(() {
                          _customMessage = value ?? false;
                        });
                      },
                title: Text(AppLocalizations.of(context)!.customMergeMessage),
                contentPadding: EdgeInsets.zero,
              ),

            if (_customMessage) ...[
              const BaseGap(Proximity.related),
              BaseTextField(
                controller: _messageController,
                label: AppLocalizations.of(context)!.mergeMessage,
                hintText: AppLocalizations.of(
                  context,
                )!.enterCustomMergeCommitMessage,
                maxLines: 3,
                enabled: !_isMerging,
              ),
            ],

            // What the chosen strategy will do, standing until the pickers
            // change it: the same member as every other notice here.
            const BaseGap(Proximity.grouped),
            _banner(
              context,
              BannerSpec(
                tone: Tone.info,
                icon: IconRole.info,
                title: _sourceBranch != null && _targetBranch != null
                    ? (_strategy == MergeStrategy.merge
                          ? AppLocalizations.of(context)!.mergeSourceIntoTarget(
                              _sourceBranch!.name,
                              _targetBranch!.name,
                            )
                          : AppLocalizations.of(
                              context,
                            )!.rebaseSourceOntoTarget(
                              _sourceBranch!.name,
                              _targetBranch!.name,
                            ))
                    : AppLocalizations.of(context)!.selectBothBranchesToMerge,
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              // The failure, as the same member with a different meaning.
              // The mark and the words each named the danger separately, and
              // the words were painted in the error FOREGROUND on the error
              // CONTAINER - a pairing nobody had measured. One tone decides
              // both halves now.
              _banner(
                context,
                BannerSpec(
                  tone: Tone.danger,
                  icon: IconRole.warningCircle,
                  title: _errorMessage!,
                ),
              ),
            ],

            // Progress indicator
            if (_isMerging) ...[
              const BaseGap(Proximity.separate),
              const LinearProgressIndicator(),
              const BaseGap(Proximity.related),
              // The italic leaves with the `TextStyle`: slanting an aside is
              // Material's answer to "this is a remark about what is
              // happening", and `TextRole.detail` is the question.
              BaseLabel(
                _strategy == MergeStrategy.merge
                    ? AppLocalizations.of(context)!.mergingBranches
                    : AppLocalizations.of(context)!.rebasingBranches,
                role: TextRole.detail,
                align: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: AppLocalizations.of(context)!.cancel,
          role: DialogActionRole.dismissive,
          enabled: !_isMerging,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: _strategy == MergeStrategy.merge
              ? AppLocalizations.of(context)!.merge
              : AppLocalizations.of(context)!.rebase,
          role: DialogActionRole.affirmative,
          icon: _strategy == MergeStrategy.merge
              ? IconRole.gitMerge
              : IconRole.gitBranch,
          enabled:
              !_isMerging && _sourceBranch != null && _targetBranch != null,
          onPressed: _mergeBranches,
        ),
      ],
    );
  }

  Future<void> _mergeBranches() async {
    if (_sourceBranch == null || _targetBranch == null) return;

    setState(() {
      _errorMessage = null;
      _isMerging = true;
    });

    try {
      final currentBranch = ref.read(currentBranchProvider).value;
      final gitActions = ref.read(gitActionsProvider);
      final gitService = ref.read(gitServiceProvider);

      // Handle remote target branches with special workflow
      if (_targetBranch!.isRemote) {
        // Step 1: Fetch latest changes from remote
        await gitService!.fetch();

        // Step 2: Get local branch name from remote branch
        // e.g., "origin/main" -> "main"
        final remoteParts = _targetBranch!.name.split('/');
        final localBranchName = remoteParts.length > 1
            ? remoteParts.sublist(1).join('/')
            : _targetBranch!.name;

        // Step 3: Create or update local tracking branch
        // First check if local branch exists
        final branches = await gitService.getBranches();
        final localBranchExists = branches.any((b) => b == localBranchName);

        if (!localBranchExists) {
          // Create new local branch tracking the remote
          await gitActions.createBranch(
            localBranchName,
            startPoint: _targetBranch!.name,
          );
        }

        // Step 4: Switch to the local tracking branch
        await gitActions.switchBranch(localBranchName);

        // Step 5: Merge source into the local branch
        if (_strategy == MergeStrategy.merge) {
          await gitActions.mergeBranch(
            _sourceBranch!.name,
            fastForwardOnly: _fastForwardOnly,
            noFastForward: _noFastForward,
            squash: _squash,
            message: _customMessage && _messageController.text.isNotEmpty
                ? _messageController.text
                : null,
          );
        } else {
          // The GitActions wrapper owns the refresh contract for the history
          // rewrite and throws on failure, so a failed rebase can no longer
          // fall through to the push below.
          // confirmed-by: this dialog itself; choosing the rebase strategy
          // and pressing the primary action is the confirmation.
          await gitActions.rebaseBranch(
            ontoBranch: _sourceBranch!.name,
            interactive: _interactive,
            preserveMerges: _preserveMerges,
          );
        }

        // Step 6: Push to remote if requested
        if (_pushAfterMerge) {
          await gitService.push(
            remote: remoteParts[0],
            branch: localBranchName,
          );
        }
      } else {
        // Normal local branch merge workflow
        // Check if we need to switch to the target branch first
        if (currentBranch != _targetBranch!.name) {
          // Switch to target branch
          await gitActions.switchBranch(_targetBranch!.name);
        }
        // Perform merge or rebase based on strategy (for local branches only)
        if (_strategy == MergeStrategy.merge) {
          // Merge source into target (which is now current)
          await gitActions.mergeBranch(
            _sourceBranch!.name,
            fastForwardOnly: _fastForwardOnly,
            noFastForward: _noFastForward,
            squash: _squash,
            message: _customMessage && _messageController.text.isNotEmpty
                ? _messageController.text
                : null,
          );
        } else {
          // Rebase target onto source. The GitActions wrapper owns the
          // refresh contract for the history rewrite and throws on failure.
          // confirmed-by: this dialog itself; choosing the rebase strategy
          // and pressing the primary action is the confirmation.
          await gitActions.rebaseBranch(
            ontoBranch: _sourceBranch!.name,
            interactive: _interactive,
            preserveMerges: _preserveMerges,
          );
        }
      }

      if (mounted) {
        // Check if there are conflicts
        final mergeState = await ref.read(mergeStateProvider.future);

        if (mergeState.isInProgress && mergeState.conflictCount > 0) {
          // Conflicts detected - close dialog and let conflict resolution screen take over
          if (mounted) {
            Navigator.of(
              context,
            ).pop(true); // Return true to indicate conflicts

            // The fill and the action's foreground left together, and that
            // is what settles the contrast defect recorded here: the action
            // said `onPrimary` over an `error` fill, a pairing that was never
            // measured for contrast. The skin now pairs both halves of the
            // notice from one tone, so the action reads against the fill it
            // actually sits on.
            //
            // The action's tooltip repeats its label because the label is the
            // only description the application has for it - and because the
            // action itself does nothing here, which is a pre-existing defect
            // this conversion carries across rather than hides.
            Overlays.notify(
              context,
              NoticeSpec(
                tone: Tone.danger,
                title: _strategy == MergeStrategy.merge
                    ? AppLocalizations.of(
                        context,
                      )!.mergeHasConflicts(mergeState.conflictCount)
                    : AppLocalizations.of(
                        context,
                      )!.rebaseHasConflicts(mergeState.conflictCount),
                actions: <NoticeAction>[
                  NoticeAction(
                    label: AppLocalizations.of(context)!.resolve,
                    tooltip: AppLocalizations.of(context)!.resolve,
                    onPressed: () {
                      // Navigate to conflict resolution (will be handled by main screen)
                    },
                  ),
                ],
              ),
            );
          }
        } else {
          // Successful merge/rebase without conflicts
          if (mounted) {
            Navigator.of(context).pop(false);

            // The merge finished and finished well, which is `success` - not
            // the git-ADDED green the fill used to borrow, a word about a
            // file's state in the index rather than about an operation.
            Overlays.notify(
              context,
              NoticeSpec(
                tone: Tone.success,
                title: _strategy == MergeStrategy.merge
                    ? AppLocalizations.of(context)!.successfullyMergedBranch(
                        _sourceBranch!.name,
                        _targetBranch!.name,
                      )
                    : AppLocalizations.of(context)!.successfullyRebasedBranch(
                        _targetBranch!.name,
                        _sourceBranch!.name,
                      ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _strategy == MergeStrategy.merge
              ? AppLocalizations.of(context)!.failedToMergeBranch(e.toString())
              : AppLocalizations.of(
                  context,
                )!.failedToRebaseBranch(e.toString());
          _isMerging = false;
        });
      }
    }
  }

  /// "This is the branch you are on", said beside the name it qualifies.
  ///
  /// Both branch lists in this dialog - the source list and the target list -
  /// stated it by hand, twice, as a `primaryContainer` box at a 4 dp corner
  /// with a 4/1 inset and a `micro` word paired against the fill. It is the
  /// same sentence `branch_list_tile.dart` has been saying through
  /// `surfaces.badge` all along, down to the word, so the two copies became
  /// one call to the member: the fill, the pairing, the inset and the corner
  /// are the skin's, and a badge's corner is derived from its own height
  /// there rather than named as a rung here.
  Widget _currentBadge(BuildContext context) => BaseBadge(
    label: AppLocalizations.of(context)!.current,
    variant: BadgeVariant.primary,
    size: BadgeSize.small,
  );

  /// **Local branches or remote ones?** - for one of the two pickers.
  ///
  /// This was an iOS-style pill built out of a `GestureDetector` inside a
  /// tinted `Container`, once per picker, plus a per-segment `_buildToggleButton`
  /// that painted the chosen half in the accent behind a 4 dp corner. "Which
  /// one of these few is it?" is `controls.choiceGroup`, and the register
  /// already names that member as the one this exact toggle is waiting for.
  ///
  /// Three things the hand-built pill could not do come with the member, and
  /// they are the reason this is a repair rather than a swap: the segments are
  /// now Tab stops with the language's own focus treatment, they wear its
  /// hover and press state layers, and a disabled segment says so - a
  /// `GestureDetector` with a null callback simply stopped responding while
  /// looking unchanged.
  Widget _branchScopeChoice(
    BuildContext context, {
    required String label,
    required bool showRemote,
    required ValueChanged<bool> onChanged,
  }) => SkinScope.render(
    context,
    (Skin skin, BuildContext inner) => skin.controls.choiceGroup<bool>(
      inner,
      ChoiceGroupSpec<bool>(
        // What the group is choosing, for a screen reader: the picker it
        // scopes, exactly as the twin toggle in create_pull_request_dialog
        // names its own. Each chip names only its half, so without this the
        // group itself would have no accessible name.
        label: label,
        options: <ChoiceOption<bool>>[
          ChoiceOption<bool>(
            value: false,
            label: AppLocalizations.of(context)!.localTab,
            enabled: !_isMerging,
          ),
          ChoiceOption<bool>(
            value: true,
            label: AppLocalizations.of(context)!.remoteTab,
            enabled: !_isMerging,
          ),
        ],
        selected: showRemote,
        // The group promises "exactly one", so re-choosing the chosen half is
        // dropped by the member and never arrives here - which is the guard
        // each hand-built segment used to write for itself.
        onSelected: onChanged,
      ),
    ),
  );
}

/// Show merge branches dialog
Future<bool?> showMergeBranchesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const MergeBranchesDialog(),
  );
}
