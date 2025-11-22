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
import '../components/base_dropdown.dart';

/// Dialog for merging a branch
class MergeBranchDialog extends ConsumerStatefulWidget {
  const MergeBranchDialog({super.key});

  @override
  ConsumerState<MergeBranchDialog> createState() => _MergeBranchDialogState();
}

class _MergeBranchDialogState extends ConsumerState<MergeBranchDialog> {
  final _messageController = TextEditingController();

  GitBranch? _selectedBranch;
  bool _isMerging = false;
  bool _noFastForward = false;
  bool _fastForwardOnly = false;
  bool _squash = false;
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
      title: AppLocalizations.of(context)!.merge,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              BodyMediumLabel(AppLocalizations.of(context)!.mergeABranchInto(currentBranch ?? 'unknown', currentBranch ?? 'unknown')),
              const SizedBox(height: AppTheme.paddingL),

              // Branch selection
              branchesAsync.when(
                data: (branches) {
                  // Filter out current branch
                  final availableBranches = branches
                      .where((b) => b.name != currentBranch)
                      .toList();

                  if (availableBranches.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppTheme.paddingM),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: BodyMediumLabel(AppLocalizations.of(context)!.noOtherBranchesAvailable),
                    );
                  }

                  return BaseDropdown<GitBranch>(
                    initialValue: _selectedBranch,
                    labelText: AppLocalizations.of(context)!.branchToMerge,
                    hintText: AppLocalizations.of(context)!.selectABranch,
                    prefixIcon: PhosphorIconsRegular.gitBranch,
                    items: availableBranches.map((branch) {
                      return BaseDropdownItem<GitBranch>(
                        value: branch,
                        builder: (context) => Row(
                          children: [
                            Icon(
                              branch.isRemote
                                  ? PhosphorIconsRegular.cloud
                                  : PhosphorIconsRegular.gitBranch,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Text(branch.name),
                            if (branch.isRemote) ...[
                              const SizedBox(width: AppTheme.paddingS),
                              BodySmallLabel(AppLocalizations.of(context)!.remote),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _isMerging
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBranch = value;
                            });
                          },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => BodyMediumLabel(
                  AppLocalizations.of(context)!.errorLoadingBranches(error.toString()),
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Merge options
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
                onChanged: _isMerging ? null : (value) {
                  setState(() {
                    _squash = value ?? false;
                  });
                },
                title: Text(AppLocalizations.of(context)!.squashCommits),
                subtitle: Text(
                  AppLocalizations.of(context)!.combineAllCommitsIntoSingleCommit,
                ),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppTheme.paddingM),

              // Custom message option
              CheckboxListTile(
                value: _customMessage,
                onChanged: _isMerging ? null : (value) {
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
                  hintText: AppLocalizations.of(context)!.enterCustomMergeCommitMessage,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.info,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    Expanded(
                      child: BodyMediumLabel(
                        _squash
                            ? AppLocalizations.of(context)!.squashMergeWillCombineAllCommits
                            : AppLocalizations.of(context)!.thisWillMergeSelectedBranch,
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
                    borderRadius: BorderRadius.circular(8),
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
                  AppLocalizations.of(context)!.mergingBranch(_selectedBranch ?? 'branch'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
          label: AppLocalizations.of(context)!.merge,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.gitMerge,
          onPressed: _isMerging || _selectedBranch == null ? null : _mergeBranch,
        ),
      ],
    );
  }

  Future<void> _mergeBranch() async {
    if (_selectedBranch == null) return;

    setState(() {
      _errorMessage = null;
      _isMerging = true;
    });

    try {
      await ref.read(gitActionsProvider).mergeBranch(
            _selectedBranch!.name,
            fastForwardOnly: _fastForwardOnly,
            noFastForward: _noFastForward,
            squash: _squash,
            message: _customMessage && _messageController.text.isNotEmpty
                ? _messageController.text
                : null,
          );

      if (mounted) {
        // Check if there are conflicts
        final mergeState = await ref.read(mergeStateProvider.future);

        if (mergeState.isInProgress && mergeState.conflictCount > 0) {
          // Conflicts detected - close dialog and let conflict resolution screen take over
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate conflicts

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.mergeHasConflicts(mergeState.conflictCount),
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
          // Successful merge without conflicts
          if (mounted) {
            Navigator.of(context).pop(false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.successfullyMergedBranch(
                    _selectedBranch!.name,
                    ref.read(currentBranchProvider).value ?? 'unknown',
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
          _errorMessage = AppLocalizations.of(context)!.failedToMergeBranch(e.toString());
          _isMerging = false;
        });
      }
    }
  }
}

/// Show merge branch dialog
Future<bool?> showMergeBranchDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const MergeBranchDialog(),
  );
}

