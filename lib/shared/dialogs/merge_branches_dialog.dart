import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../components/base_layout.dart';
import '../components/base_icon.dart';

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
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: BaseInset(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.noOtherBranchesAvailable,
                        role: TextRole.body,
                      ),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.paddingXS,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusS,
                                          ),
                                        ),
                                        // The pill states the foreground its
                                        // own fill pairs with; the word inside
                                        // reads it.
                                        child: DefaultTextStyle.merge(
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                          child: BaseLabel(
                                            AppLocalizations.of(
                                              context,
                                            )!.current,
                                            role: TextRole.micro,
                                          ),
                                        ),
                                      ),
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
                        // Toggle switch for source
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const BaseGap(Proximity.related),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildToggleButton(
                                    context,
                                    label: AppLocalizations.of(
                                      context,
                                    )!.localTab,
                                    isSelected: !_showRemoteBranchesForSource,
                                    onTap: _isMerging
                                        ? null
                                        : () {
                                            if (_showRemoteBranchesForSource) {
                                              setState(() {
                                                _showRemoteBranchesForSource =
                                                    false;
                                                _sourceBranch = null;
                                                _initialized = false;
                                              });
                                            }
                                          },
                                  ),
                                  _buildToggleButton(
                                    context,
                                    label: AppLocalizations.of(
                                      context,
                                    )!.remoteTab,
                                    isSelected: _showRemoteBranchesForSource,
                                    onTap: _isMerging
                                        ? null
                                        : () {
                                            if (!_showRemoteBranchesForSource) {
                                              setState(() {
                                                _showRemoteBranchesForSource =
                                                    true;
                                                _sourceBranch = null;
                                                _initialized = false;
                                              });
                                            }
                                          },
                                  ),
                                ],
                              ),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.paddingXS,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusS,
                                          ),
                                        ),
                                        // The pill states the foreground its
                                        // own fill pairs with; the word inside
                                        // reads it.
                                        child: DefaultTextStyle.merge(
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                          child: BaseLabel(
                                            AppLocalizations.of(
                                              context,
                                            )!.current,
                                            role: TextRole.micro,
                                          ),
                                        ),
                                      ),
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
                        // Toggle switch for target
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const BaseGap(Proximity.related),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildToggleButton(
                                    context,
                                    label: AppLocalizations.of(
                                      context,
                                    )!.localTab,
                                    isSelected: !_showRemoteBranchesForTarget,
                                    onTap: _isMerging
                                        ? null
                                        : () {
                                            if (_showRemoteBranchesForTarget) {
                                              setState(() {
                                                _showRemoteBranchesForTarget =
                                                    false;
                                                _targetBranch = null;
                                              });
                                            }
                                          },
                                  ),
                                  _buildToggleButton(
                                    context,
                                    label: AppLocalizations.of(
                                      context,
                                    )!.remoteTab,
                                    isSelected: _showRemoteBranchesForTarget,
                                    onTap: _isMerging
                                        ? null
                                        : () {
                                            if (!_showRemoteBranchesForTarget) {
                                              setState(() {
                                                _showRemoteBranchesForTarget =
                                                    true;
                                                _targetBranch = null;
                                              });
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Show info message when remote target is selected
                    if (_targetBranch?.isRemote == true) ...[
                      const BaseGap(Proximity.grouped),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          // The panel's FILL and its BORDER, both washes of
                          // colours this notice is painted in rather than
                          // foregrounds it states. They leave with the
                          // surface in P5; only the words inside carry tones.
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        // The panel is painted in `primaryContainer`, so it
                        // publishes the foreground that pairs with it once,
                        // here, instead of four lines below each naming it.
                        child: BaseInset(
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const BaseIcon(
                                      IconRole.info,
                                      scale: ControlScale.compact,
                                      tone: Tone.accent,
                                    ),
                                    const BaseGap(Proximity.related),
                                    Expanded(
                                      child: BaseLabel(
                                        'Merging to remote branch',
                                        role: TextRole.sectionTitle,
                                        tone: Tone.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const BaseGap(Proximity.related),
                                BaseLabel(
                                  'This will perform the following steps:\n'
                                  '1. Fetch latest changes from remote\n'
                                  '2. Create/update local tracking branch\n'
                                  '3. Merge ${_sourceBranch?.name ?? 'source'} into local branch\n'
                                  '4. ${_pushAfterMerge ? 'Push changes to remote' : 'Keep changes local (you can push later)'}',
                                  role: TextRole.detail,
                                ),
                                const BaseGap(Proximity.grouped),
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
                            ),
                          ),
                        ),
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

            // Info card
            const BaseGap(Proximity.grouped),
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
                        _sourceBranch != null && _targetBranch != null
                            ? (_strategy == MergeStrategy.merge
                                  ? AppLocalizations.of(
                                      context,
                                    )!.mergeSourceIntoTarget(
                                      _sourceBranch!.name,
                                      _targetBranch!.name,
                                    )
                                  : AppLocalizations.of(
                                      context,
                                    )!.rebaseSourceOntoTarget(
                                      _sourceBranch!.name,
                                      _targetBranch!.name,
                                    ))
                            : AppLocalizations.of(
                                context,
                              )!.selectBothBranchesToMerge,
                        role: TextRole.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: BaseInset(
                  child: Row(
                    children: [
                      // The mark says what the message beside it already says,
                      // so it says it the same way: the danger this label had
                      // already named, stated once as a meaning instead of a
                      // second time as a scheme role. The mark stated no size
                      // at all and took whatever the dialog's ambient theme
                      // handed it; the info banner a few lines above asks for
                      // the ordinary size, so the difference was drift rather
                      // than a distinction and both now say the same rung.
                      const BaseIcon(IconRole.warningCircle, tone: Tone.danger),
                      const BaseGap(Proximity.related),
                      Expanded(
                        child: BaseLabel(
                          _errorMessage!,
                          role: TextRole.body,
                          tone: Tone.danger,
                        ),
                      ),
                    ],
                  ),
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _strategy == MergeStrategy.merge
                      ? AppLocalizations.of(
                          context,
                        )!.mergeHasConflicts(mergeState.conflictCount)
                      : AppLocalizations.of(
                          context,
                        )!.rebaseHasConflicts(mergeState.conflictCount),
                ),
                // A surface FILL, not a foreground: this is what the notice
                // is painted in, and its words are paired against it. The
                // whole `SnackBar` is `overlays.notify`, and the fill leaves
                // with it - which is also what finally settles the mispaired
                // `onPrimary` recorded on the action below.
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: AppLocalizations.of(context)!.resolve,
                  // A foreground, and the one read in this file the mapping
                  // would convert - except that `Tone` reaches text only
                  // through `BaseLabel`, and a `SnackBarAction` takes a
                  // `Color` and builds its own label. The whole notice is a
                  // P5 member (`NoticeLifetime` already exists for it), and
                  // the word goes with it. Recorded while it waits: this says
                  // `onPrimary` over an `error` fill, which is the wrong
                  // pairing and a real contrast defect - correcting it to the
                  // danger tone's own on-colour is a change of appearance, so
                  // it is reported here rather than smuggled into a rename.
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () {
                    // Navigate to conflict resolution (will be handled by main screen)
                  },
                ),
              ),
            );
          }
        } else {
          // Successful merge/rebase without conflicts
          if (mounted) {
            Navigator.of(context).pop(false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _strategy == MergeStrategy.merge
                      ? AppLocalizations.of(context)!.successfullyMergedBranch(
                          _sourceBranch!.name,
                          _targetBranch!.name,
                        )
                      : AppLocalizations.of(context)!.successfullyRebasedBranch(
                          _targetBranch!.name,
                          _sourceBranch!.name,
                        ),
                ),
                backgroundColor: context.gitColors.added,
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

  /// Build iOS-style toggle button
  Widget _buildToggleButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // The chosen segment's FILL, not a foreground: this is what the
          // segment is painted in, and the word below is paired against it.
          // It leaves with `controls.choiceGroup`, the member that owns a
          // segmented control's selected surface.
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        // The chosen segment is painted in the accent, so its word is the
        // foreground that goes ON the accent; the segment beside it is present
        // but secondary to the one that is chosen. Those are the two meanings
        // `onPrimary` and `onSurfaceVariant` were Material's answers to, and
        // the word can now carry them itself instead of being handed a
        // `TextStyle` from outside.
        child: BaseLabel(
          label,
          role: TextRole.micro,
          tone: isSelected ? Tone.onAccent : Tone.muted,
        ),
      ),
    );
  }
}

/// Show merge branches dialog
Future<bool?> showMergeBranchesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const MergeBranchesDialog(),
  );
}
