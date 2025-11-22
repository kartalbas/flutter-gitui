import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../components/base_dialog.dart';
import '../components/base_menu_item.dart';
import '../components/base_dropdown.dart';

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
      icon: PhosphorIconsRegular.gitMerge,
      title: AppLocalizations.of(context)!.mergeBranches,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BodyMediumLabel(
              AppLocalizations.of(context)!.selectSourceAndTargetBranches,
            ),
            const SizedBox(height: AppTheme.paddingL),

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
                    padding: const EdgeInsets.all(AppTheme.paddingM),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.paddingS),
                    ),
                    child: BodyMediumLabel(
                      AppLocalizations.of(context)!.noOtherBranchesAvailable,
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
                            labelText: AppLocalizations.of(
                              context,
                            )!.sourceBranch,
                            hintText: AppLocalizations.of(
                              context,
                            )!.selectSourceBranch,
                            prefixIcon: PhosphorIconsRegular.gitBranch,
                            items: filteredSourceBranches.map((branch) {
                              return BaseDropdownItem(
                                value: branch,
                                builder: (context) => Row(
                                  children: [
                                    Icon(
                                      branch.isRemote
                                          ? PhosphorIconsRegular.cloud
                                          : PhosphorIconsRegular.gitBranch,
                                      size: 14,
                                    ),
                                    const SizedBox(width: AppTheme.paddingS),
                                    Expanded(
                                      child: MenuItemLabel(
                                        branch.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (branch.name == currentBranch) ...[
                                      const SizedBox(width: AppTheme.paddingS),
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
                                            3,
                                          ),
                                        ),
                                        child: LabelSmallLabel(
                                          AppLocalizations.of(context)!.current,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
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
                        const SizedBox(width: AppTheme.paddingM),
                        // Toggle switch for source
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: AppTheme.paddingS),
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

                    const SizedBox(height: AppTheme.paddingM),

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
                            prefixIcon: PhosphorIconsRegular.gitBranch,
                            items: availableTargetBranches.map((branch) {
                              return BaseDropdownItem(
                                value: branch,
                                builder: (context) => Row(
                                  children: [
                                    Icon(
                                      branch.isRemote
                                          ? PhosphorIconsRegular.cloud
                                          : PhosphorIconsRegular.gitBranch,
                                      size: 14,
                                    ),
                                    const SizedBox(width: AppTheme.paddingS),
                                    Expanded(
                                      child: MenuItemLabel(
                                        branch.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (branch.name == currentBranch) ...[
                                      const SizedBox(width: AppTheme.paddingS),
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
                                            3,
                                          ),
                                        ),
                                        child: LabelSmallLabel(
                                          AppLocalizations.of(context)!.current,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
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
                        const SizedBox(width: AppTheme.paddingM),
                        // Toggle switch for target
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: AppTheme.paddingS),
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
                      const SizedBox(height: AppTheme.paddingM),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.paddingM),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.info,
                                  size: AppTheme.iconS,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppTheme.paddingS),
                                Expanded(
                                  child: TitleSmallLabel(
                                    'Merging to remote branch',
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.paddingS),
                            BodySmallLabel(
                              'This will perform the following steps:\n'
                              '1. Fetch latest changes from remote\n'
                              '2. Create/update local tracking branch\n'
                              '3. Merge ${_sourceBranch?.name ?? 'source'} into local branch\n'
                              '4. ${_pushAfterMerge ? 'Push changes to remote' : 'Keep changes local (you can push later)'}',
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(height: AppTheme.paddingM),
                            CheckboxListTile(
                              value: _pushAfterMerge,
                              onChanged: _isMerging
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _pushAfterMerge = value ?? true;
                                      });
                                    },
                              title: BodyMediumLabel(
                                'Push to remote after merge',
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              subtitle: BodySmallLabel(
                                _pushAfterMerge
                                    ? 'Changes will be immediately visible on remote'
                                    : 'You can review and push manually later',
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => BodyMediumLabel(
                AppLocalizations.of(
                  context,
                )!.errorLoadingBranches(error.toString()),
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Strategy selector
            TitleSmallLabel(AppLocalizations.of(context)!.strategy),
            const SizedBox(height: AppTheme.paddingS),
            SegmentedButton<MergeStrategy>(
              segments: [
                ButtonSegment(
                  value: MergeStrategy.merge,
                  label: Text(AppLocalizations.of(context)!.merge),
                  icon: const Icon(
                    PhosphorIconsRegular.gitMerge,
                    size: AppTheme.paddingM,
                  ),
                ),
                ButtonSegment(
                  value: MergeStrategy.rebase,
                  label: Text(AppLocalizations.of(context)!.rebase),
                  icon: const Icon(
                    PhosphorIconsRegular.gitBranch,
                    size: AppTheme.paddingM,
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
            const SizedBox(height: AppTheme.paddingL),

            // Merge/Rebase options (conditional based on strategy)
            if (_strategy == MergeStrategy.merge) ...[
              TitleSmallLabel(AppLocalizations.of(context)!.mergeOptions),
              const SizedBox(height: AppTheme.paddingS),

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
              TitleSmallLabel(AppLocalizations.of(context)!.rebaseOptions),
              const SizedBox(height: AppTheme.paddingS),

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

            const SizedBox(height: AppTheme.paddingM),

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
              const SizedBox(height: AppTheme.paddingS),
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
            const SizedBox(height: AppTheme.paddingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.paddingS),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.info, size: 20),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodyMediumLabel(
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
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: AppTheme.paddingM),
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.paddingS),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    Expanded(
                      child: BodyMediumLabel(
                        _errorMessage!,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Progress indicator
            if (_isMerging) ...[
              const SizedBox(height: AppTheme.paddingL),
              const LinearProgressIndicator(),
              const SizedBox(height: AppTheme.paddingS),
              BaseLabel(
                _strategy == MergeStrategy.merge
                    ? AppLocalizations.of(context)!.mergingBranches
                    : AppLocalizations.of(context)!.rebasingBranches,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: _isMerging ? null : () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: _strategy == MergeStrategy.merge
              ? AppLocalizations.of(context)!.merge
              : AppLocalizations.of(context)!.rebase,
          variant: ButtonVariant.primary,
          leadingIcon: _strategy == MergeStrategy.merge
              ? PhosphorIconsRegular.gitMerge
              : PhosphorIconsRegular.gitBranch,
          onPressed:
              _isMerging || _sourceBranch == null || _targetBranch == null
              ? null
              : _mergeBranches,
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
          await gitService.rebaseBranch(
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
          // Rebase target onto source
          await gitService!.rebaseBranch(
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
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: AppLocalizations.of(context)!.resolve,
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
                backgroundColor: AppTheme.gitAdded,
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
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: LabelSmallLabel(
          label,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
