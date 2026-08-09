import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../components/base_layout.dart';

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
      icon: IconRole.gitMerge,
      title: AppLocalizations.of(context)!.merge,
      // Enter merges once a branch is chosen; Esc cancels.
      onSubmit: _isMerging || _selectedBranch == null ? null : _mergeBranch,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BaseLabel(
              AppLocalizations.of(context)!.mergeABranchInto(
                currentBranch ?? 'unknown',
                currentBranch ?? 'unknown',
              ),
              role: TextRole.body,
            ),
            const BaseGap(Proximity.separate),

            // Branch selection
            branchesAsync.when(
              data: (branches) {
                // Filter out current branch
                final availableBranches = branches
                    .where((b) => b.name != currentBranch)
                    .toList();

                if (availableBranches.isEmpty) {
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

                return BaseDropdown<GitBranch>(
                  initialValue: _selectedBranch,
                  autofocus: true,
                  labelText: AppLocalizations.of(context)!.branchToMerge,
                  hintText: AppLocalizations.of(context)!.selectABranch,
                  prefixIcon: IconRole.gitBranch,
                  items: availableBranches.map((branch) {
                    return BaseDropdownItem<GitBranch>(
                      value: branch,
                      builder: (context) => Row(
                        children: [
                          // A dense mark inside a menu entry: the row is one
                          // line tall and the mark is part of the line rather
                          // than something standing beside it.
                          BaseIcon(
                            branch.isRemote
                                ? IconRole.cloud
                                : IconRole.gitBranch,
                            scale: ControlScale.compact,
                          ),
                          const BaseGap(Proximity.related),
                          Text(branch.name),
                          if (branch.isRemote) ...[
                            const BaseGap(Proximity.related),
                            BaseLabel(
                              AppLocalizations.of(context)!.remote,
                              role: TextRole.detail,
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
                            _selectedBranch = value;
                          });
                        },
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
            const BaseGap(Proximity.grouped),

            // Merge options
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
                AppLocalizations.of(context)!.combineAllCommitsIntoSingleCommit,
              ),
              contentPadding: EdgeInsets.zero,
            ),

            const BaseGap(Proximity.grouped),

            // Custom message option
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
                        _squash
                            ? AppLocalizations.of(
                                context,
                              )!.squashMergeWillCombineAllCommits
                            : AppLocalizations.of(
                                context,
                              )!.thisWillMergeSelectedBranch,
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
                AppLocalizations.of(
                  context,
                )!.mergingBranch(_selectedBranch ?? 'branch'),
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
          label: AppLocalizations.of(context)!.merge,
          role: DialogActionRole.affirmative,
          icon: IconRole.gitMerge,
          enabled: !_isMerging && _selectedBranch != null,
          onPressed: _mergeBranch,
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
      await ref
          .read(gitActionsProvider)
          .mergeBranch(
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
            Navigator.of(
              context,
            ).pop(true); // Return true to indicate conflicts

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  )!.mergeHasConflicts(mergeState.conflictCount),
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
                backgroundColor: context.gitColors.added,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.failedToMergeBranch(e.toString());
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
