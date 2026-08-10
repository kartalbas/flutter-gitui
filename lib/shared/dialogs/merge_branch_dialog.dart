import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        DialogRouteSpec,
        IconRole,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_toggle_row.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../components/base_layout.dart';
import '../../core/services/notification_service.dart';

/// One standing statement about the whole dialog, drawn by the skin.
///
/// The three notices in this file - "there is nothing to merge", "here is
/// what merging will do" and "the merge failed" - were three copies of one
/// hand-painted container: a tonal fill, a 12 dp corner, a 16 dp inset and a
/// line of words. That construction is `surfaces.banner`, so it leaves whole
/// and the corner leaves with it; what stays here is the tone, which is the
/// only half of the decision the application owns.
Widget _banner(BuildContext context, BannerSpec spec) => SkinScope.render(
  context,
  (Skin skin, BuildContext inner) => skin.surfaces.banner(inner, spec),
);

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
                  // There is nothing to pick, and saying so is a statement
                  // about the whole dialog rather than a control: the picker
                  // is replaced by the notice that explains its absence. It
                  // carries no mark, exactly as it did before - the sentence
                  // is the whole of it.
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
            BaseToggleRow(
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
              label: AppLocalizations.of(context)!.fastForwardOnly,
              description: AppLocalizations.of(
                context,
              )!.abortIfFastForwardNotPossible,
            ),

            // No fast-forward
            BaseToggleRow(
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
              label: AppLocalizations.of(context)!.noFastForward,
              description: AppLocalizations.of(
                context,
              )!.alwaysCreateMergeCommit,
            ),

            // Squash
            BaseToggleRow(
              value: _squash,
              onChanged: _isMerging
                  ? null
                  : (value) {
                      setState(() {
                        _squash = value ?? false;
                      });
                    },
              label: AppLocalizations.of(context)!.squashCommits,
              description: AppLocalizations.of(
                context,
              )!.combineAllCommitsIntoSingleCommit,
            ),

            const BaseGap(Proximity.grouped),

            // Custom message option
            BaseToggleRow(
              value: _customMessage,
              onChanged: _isMerging
                  ? null
                  : (value) {
                      setState(() {
                        _customMessage = value ?? false;
                      });
                    },
              label: AppLocalizations.of(context)!.customMergeMessage,
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

            // What the merge will do, standing until the options change it.
            // The same member as the two notices around it, differing only in
            // what it means.
            const BaseGap(Proximity.grouped),
            _banner(
              context,
              BannerSpec(
                tone: Tone.info,
                icon: IconRole.info,
                title: _squash
                    ? AppLocalizations.of(
                        context,
                      )!.squashMergeWillCombineAllCommits
                    : AppLocalizations.of(context)!.thisWillMergeSelectedBranch,
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              // The failure, as the same member with a different meaning.
              // The mark and the words each named the danger separately and
              // the words were painted in the error FOREGROUND on the error
              // CONTAINER - a pairing nobody had measured. One tone now
              // decides both halves, so the message reads against the fill it
              // actually sits on.
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

            // The same conversion as `merge_branches_dialog.dart`, and the
            // same contrast defect settled: the action said `onPrimary` over
            // an `error` fill, and the skin now pairs both halves of the
            // notice from one tone.
            //
            // The action's tooltip repeats its label because the label is the
            // only description the application has for it - and the action
            // itself does nothing here, a pre-existing defect this conversion
            // carries across rather than hides.
            NotificationService.showError(
              context,
              AppLocalizations.of(
                context,
              )!.mergeHasConflicts(mergeState.conflictCount),
            );
          }
        } else {
          // Successful merge without conflicts
          if (mounted) {
            Navigator.of(context).pop(false);

            // `success`, not the git-added green: see the sibling dialog.
            NotificationService.showSuccess(
              context,
              AppLocalizations.of(context)!.successfullyMergedBranch(
                _selectedBranch!.name,
                ref.read(currentBranchProvider).value ?? 'unknown',
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
  return Overlays.dialogFrom<bool>(
    context,
    route: DialogRouteSpec(
      title: AppLocalizations.of(context)!.merge,
      barrierDismissible: false,
    ),
    builder: (context) => const MergeBranchDialog(),
  );
}
