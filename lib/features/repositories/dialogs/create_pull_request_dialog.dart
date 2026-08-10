import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ChoiceGroupSpec,
        ChoiceOption,
        DialogRouteSpec,
        IconRole,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        SuggestItem,
        TextRole,
        Tone;
import 'package:timeago/timeago.dart' as timeago;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_toggle_row.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_dropdown.dart';
import '../../../generated/app_localizations.dart';
import '../../../core/git/models/branch.dart';
import '../../../shared/components/base_layout.dart';

/// Result of the create pull request dialog
class CreatePullRequestResult {
  final String title;
  final String description;
  final String sourceBranch;
  final String baseBranch;
  final bool draft;

  const CreatePullRequestResult({
    required this.title,
    required this.description,
    required this.sourceBranch,
    required this.baseBranch,
    this.draft = false,
  });
}

/// Dialog for creating a pull request
class CreatePullRequestDialog extends StatefulWidget {
  final String currentBranch;
  final List<GitBranch> availableBranches;

  const CreatePullRequestDialog({
    super.key,
    required this.currentBranch,
    required this.availableBranches,
  });

  @override
  State<CreatePullRequestDialog> createState() =>
      _CreatePullRequestDialogState();
}

class _CreatePullRequestDialogState extends State<CreatePullRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late GitBranch _selectedSourceBranch;
  late GitBranch _selectedBaseBranch;
  bool _isDraft = false;
  bool _showRemoteBranchesForSource = false;
  bool _showRemoteBranchesForTarget = false;

  @override
  void initState() {
    super.initState();

    // Set source branch to current branch
    _selectedSourceBranch = widget.availableBranches.firstWhere(
      (branch) => branch.name == widget.currentBranch,
      orElse: () => widget.availableBranches.isNotEmpty
          ? widget.availableBranches.first
          : const GitBranch(
              name: 'HEAD',
              fullName: 'HEAD',
              isLocal: true,
              isRemote: false,
              isCurrent: true,
            ),
    );

    // Try to detect main branch from available branches for target
    final mainBranches = ['main', 'master', 'develop', 'development'];
    _selectedBaseBranch = widget.availableBranches.firstWhere(
      (branch) =>
          mainBranches.contains(branch.name) &&
          branch.name != widget.currentBranch,
      orElse: () => widget.availableBranches.firstWhere(
        (branch) => branch.name != widget.currentBranch,
        orElse: () => widget.availableBranches.isNotEmpty
            ? widget.availableBranches.first
            : const GitBranch(
                name: 'main',
                fullName: 'refs/heads/main',
                isLocal: true,
                isRemote: false,
                isCurrent: false,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Filter branches for source dropdown
    var sourceBranches = _showRemoteBranchesForSource
        ? widget.availableBranches.toList()
        : widget.availableBranches.where((b) => !b.isRemote).toList();

    // Filter branches for target/base dropdown
    var targetBranches = _showRemoteBranchesForTarget
        ? widget.availableBranches.toList()
        : widget.availableBranches.where((b) => !b.isRemote).toList();

    // Sort by last commit date (newest first), with null dates at the end
    void sortBranches(List<GitBranch> branches) {
      branches.sort((a, b) {
        if (a.lastCommitDate == null && b.lastCommitDate == null) {
          return a.name.compareTo(b.name);
        }
        if (a.lastCommitDate == null) return 1;
        if (b.lastCommitDate == null) return -1;
        return b.lastCommitDate!.compareTo(a.lastCommitDate!);
      });
    }

    sortBranches(sourceBranches);
    sortBranches(targetBranches);

    // Filter out selected source branch from target branches to avoid same branch PR
    targetBranches = targetBranches
        .where((branch) => branch.name != _selectedSourceBranch.name)
        .toList();

    return BaseDialog(
      title: l10n.createPullRequestDialogTitle,
      // Drawn at Phosphor BOLD before the conversion, like the affirmative
      // action's mark further down. Same glyph, heavier stroke; a role
      // carries no weight (#249 conflict C3) so both now take the ordinary
      // one. Recorded and pinned, with the measurement, by
      // `test/shared/icons/icon_weight_census_test.dart`: 6 of the 72
      // `BaseDialog.icon` sites were bold, and the pull-request mark itself
      // is drawn at the ordinary stroke everywhere else it appears.
      icon: IconRole.gitPullRequest,
      // The description field is multiline; Enter inside it writes a newline,
      // Enter anywhere else creates. _handleCreate validates the form itself.
      onSubmit: _handleCreate,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source branch selection with search
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // `controls.suggestField`, reached through the one façade
                  // the application keeps for it. The branch list is stated as
                  // DATA - a value, the words it is called, what distinguishes
                  // it and what KIND of branch it is - and the skin draws the
                  // row, the overlay and the search box from it.
                  //
                  // The validator this used to carry is gone with the hand-built
                  // `FormField`: the member is unhosted by decision
                  // (`Fields.suggest`), and the rule it enforced - "a source
                  // branch must be named" - cannot fail here, because
                  // `_selectedSourceBranch` is non-nullable and is set in
                  // `initState`.
                  child: SearchableBaseDropdown<GitBranch>(
                    value: _selectedSourceBranch,
                    label: l10n.sourceBranchLabel,
                    prefixIcon: IconRole.gitBranch,
                    // Two sentences, two jobs: the closed field's own words
                    // while nothing is chosen, and the search box's while
                    // nothing is typed. The first was silently dropped when
                    // the spec had one slot doing both.
                    placeholder: l10n.selectSourceBranch,
                    searchHint: l10n.searchBranches,
                    items: sourceBranches.map((branch) {
                      final lastCommitText = branch.lastCommitDate != null
                          ? timeago.format(
                              branch.lastCommitDate!,
                              locale: 'en_short',
                            )
                          : null;
                      return SuggestItem<GitBranch>(
                        value: branch,
                        label: branch.name,
                        detail: lastCommitText,
                        // A meaning rather than a glyph: which mark stands for
                        // "this branch lives on a remote" is the skin's answer.
                        icon: branch.isRemote
                            ? IconRole.cloud
                            : IconRole.gitBranch,
                      );
                    }).toList(),
                    onSelected: (value) {
                      setState(() {
                        _selectedSourceBranch = value;
                        // The target dropdown hides the source branch, so a base
                        // that just became the source is no longer selectable and
                        // would otherwise survive as a same-branch pull request.
                        if (_selectedBaseBranch.name ==
                            _selectedSourceBranch.name) {
                          _resetBranchSelection();
                        }
                      });
                    },
                  ),
                ),
                const BaseGap(Proximity.grouped),
                // Toggle switch for source branch
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(
                      height: AppTheme.paddingL + AppTheme.paddingS,
                    ),
                    _branchScopeToggle(
                      label: l10n.sourceBranchLabel,
                      localLabel: l10n.localTab,
                      remoteLabel: l10n.remoteTab,
                      showRemote: _showRemoteBranchesForSource,
                      onChanged: (bool showRemote) {
                        setState(() {
                          _showRemoteBranchesForSource = showRemote;
                          _resetSourceBranchSelection();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),

            const BaseGap(Proximity.separate),

            // Base branch selection with search
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // The same member as the source field above, for the same
                  // reason; `_selectedBaseBranch` is non-nullable too, so the
                  // dropped validator was equally unreachable here.
                  child: SearchableBaseDropdown<GitBranch>(
                    value: _selectedBaseBranch,
                    label: l10n.targetBranchLabel,
                    prefixIcon: IconRole.gitBranch,
                    placeholder: l10n.selectTargetBranch,
                    searchHint: l10n.searchBranches,
                    items: targetBranches.map((branch) {
                      final lastCommitText = branch.lastCommitDate != null
                          ? timeago.format(
                              branch.lastCommitDate!,
                              locale: 'en_short',
                            )
                          : null;
                      return SuggestItem<GitBranch>(
                        value: branch,
                        label: branch.name,
                        detail: lastCommitText,
                        icon: branch.isRemote
                            ? IconRole.cloud
                            : IconRole.gitBranch,
                      );
                    }).toList(),
                    onSelected: (value) {
                      setState(() {
                        _selectedBaseBranch = value;
                      });
                    },
                  ),
                ),
                const BaseGap(Proximity.grouped),
                // Toggle switch for target branch
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(
                      height: AppTheme.paddingL + AppTheme.paddingS,
                    ),
                    _branchScopeToggle(
                      label: l10n.targetBranchLabel,
                      localLabel: l10n.localTab,
                      remoteLabel: l10n.remoteTab,
                      showRemote: _showRemoteBranchesForTarget,
                      onChanged: (bool showRemote) {
                        setState(() {
                          _showRemoteBranchesForTarget = showRemote;
                          _resetBranchSelection();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),

            const BaseGap(Proximity.separate),

            // PR Title
            BaseLabel(l10n.pullRequestTitleLabel, role: TextRole.control),
            const BaseGap(Proximity.related),
            BaseTextField(
              controller: _titleController,
              hintText: l10n.enterPRTitle,
              prefixIcon: IconRole.textT,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterPRTitleValidation;
                }
                return null;
              },
              autofocus: true,
            ),

            const BaseGap(Proximity.separate),

            // PR Description
            BaseLabel(l10n.descriptionLabel, role: TextRole.control),
            const BaseGap(Proximity.related),
            BaseTextField(
              controller: _descriptionController,
              hintText: l10n.enterPRDescription,
              prefixIcon: IconRole.textAlignLeft,
              maxLines: 5,
            ),

            const BaseGap(Proximity.separate),

            // Draft checkbox
            BaseToggleRow(
              value: _isDraft,
              onChanged: (value) {
                setState(() {
                  _isDraft = value ?? false;
                });
              },
              label: l10n.createAsDraftLabel,
              description: l10n.draftPRDescription,
            ),

            const BaseGap(Proximity.related),

            // "This is worth knowing about the whole dialog", which is
            // `surfaces.banner` - and this is the FIFTH copy of one
            // construction, not a one-off: a tinted box, an `info` mark and a
            // sentence of supporting prose. The other four (the two in
            // `merge_branch_dialog.dart`, and the ones in `bisect_dialog.dart`
            // and `rebase_dialog.dart`) became this member already. The note
            // that stood here kept this one back because its sentence is set a
            // type step quieter than theirs - but the two type steps ARE the
            // drift the earlier pass named when it found the family, so
            // keeping the quieter one out preserved exactly the disagreement
            // the member exists to end.
            //
            // The whole construction goes with it: the wash, the corner, the
            // inset, the mark, the gap and the `DefaultTextStyle.merge` that
            // was pairing a foreground to a container this dialog painted
            // itself - each of them is something `BannerSpec` says once.
            //
            // What moves: the fill goes from `secondaryContainer` at 30 % to
            // the member's full-strength `primaryContainer` (Material answers
            // `info` and `accent` with the same role, a collapse the contract
            // records at material_ink.dart:173), the mark goes from
            // `secondary` at the 16 dp rung to `onPrimaryContainer` at the
            // banner's own size, and the sentence rises from `TextRole.detail`
            // to the member's `titleMedium`. Louder than it was, and the
            // member's answer is the right one: this is the dialog telling the
            // user that creating a PR here opens their forge in a browser -
            // the same class of statement as "this will merge the selected
            // branch" two dialogs over, which has been drawn at exactly this
            // volume since it converted.
            SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.banner(
                inner,
                BannerSpec(
                  tone: Tone.info,
                  icon: IconRole.info,
                  title: l10n.prInfoMessage,
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.createPRButton,
          role: DialogActionRole.affirmative,
          // Bold before the conversion; see the header mark above. Of the 16
          // `DialogAction.icon` sites in the application, 2 were bold and 14
          // were not, so the heavier stroke here was drift rather than a
          // statement the action was making.
          icon: IconRole.gitPullRequest,
          onPressed: _handleCreate,
        ),
      ],
    );
  }

  void _handleCreate() {
    if (_formKey.currentState?.validate() ?? false) {
      final result = CreatePullRequestResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        sourceBranch: _selectedSourceBranch.name,
        baseBranch: _selectedBaseBranch.name,
        draft: _isDraft,
      );
      Navigator.of(context).pop(result);
    }
  }

  void _resetSourceBranchSelection() {
    final newFilteredBranches = _showRemoteBranchesForSource
        ? widget.availableBranches
        : widget.availableBranches.where((b) => !b.isRemote).toList();
    _selectedSourceBranch = newFilteredBranches.firstWhere(
      (branch) => branch.name == widget.currentBranch,
      orElse: () => newFilteredBranches.isNotEmpty
          ? newFilteredBranches.first
          : const GitBranch(
              name: 'HEAD',
              fullName: 'HEAD',
              isLocal: true,
              isRemote: false,
              isCurrent: true,
            ),
    );
    // Switching the source scope can land on the branch already used as base.
    if (_selectedBaseBranch.name == _selectedSourceBranch.name) {
      _resetBranchSelection();
    }
  }

  void _resetBranchSelection() {
    final mainBranches = ['main', 'master', 'develop', 'development'];
    final newFilteredBranches = _showRemoteBranchesForTarget
        ? widget.availableBranches
        : widget.availableBranches.where((b) => !b.isRemote).toList();
    _selectedBaseBranch = newFilteredBranches.firstWhere(
      (branch) =>
          mainBranches.contains(branch.name) &&
          branch.name != _selectedSourceBranch.name,
      orElse: () => newFilteredBranches.firstWhere(
        (branch) => branch.name != _selectedSourceBranch.name,
        orElse: () => newFilteredBranches.isNotEmpty
            ? newFilteredBranches.first
            : const GitBranch(
                name: 'main',
                fullName: 'refs/heads/main',
                isLocal: true,
                isRemote: false,
                isCurrent: false,
              ),
      ),
    );
  }

  /// Whether a branch field offers local branches or all of them, as
  /// `controls.choiceGroup`.
  ///
  /// Local-versus-remote is one single-choice question, which is the member's
  /// own sentence ("pick exactly one"), and stating it that way deletes the
  /// whole hand-built segmented control: the surrounding box's
  /// `surfaceContainerHighest` fill and its corner, each segment's own fill
  /// and corner, the 12/6 inset inside each, and the `Tone.onAccent` that was
  /// truthful only while THIS widget painted the accent behind the chosen
  /// segment. Both notes that stood on those two pieces predicted exactly
  /// this and named this member.
  ///
  /// **It also closes a keyboard hole.** Each segment was a bare
  /// `GestureDetector`: a tap target with no state layer, no focus and no
  /// keyboard activation, which this repository's own rules forbid outright
  /// and which made the two switches mouse-only. The member's chips take
  /// focus, wear hover, focus and press layers, and activate on Enter and
  /// Space, so Tab now walks source field → source scope → target field →
  /// target scope in reading order.
  ///
  /// The picture changes with the construction, deliberately: two chips in a
  /// wrap where there was one joined segmented box, with selection said by
  /// the chip's own container and `secondary` outline (CHIP-003) rather than
  /// by a solid accent fill. The chips also carry the group's accessible name,
  /// which the hand-built pair never had.
  ///
  /// The `SizedBox` above each call site stays: it is the neighbouring
  /// dropdown's label-region height, hand-copied so the switch aligns with
  /// that field's input box, and it is registered as a vocabulary gap for
  /// exactly the reason it survives here - the member replaces the toggle and
  /// does not absorb a metric of the control beside it.
  Widget _branchScopeToggle({
    required String label,
    required String localLabel,
    required String remoteLabel,
    required bool showRemote,
    required ValueChanged<bool> onChanged,
  }) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.controls.choiceGroup<bool>(
        inner,
        ChoiceGroupSpec<bool>(
          label: label,
          options: <ChoiceOption<bool>>[
            ChoiceOption<bool>(value: false, label: localLabel),
            ChoiceOption<bool>(value: true, label: remoteLabel),
          ],
          selected: showRemote,
          onSelected: onChanged,
        ),
      );
    });
  }
}

/// Show create pull request dialog
Future<CreatePullRequestResult?> showCreatePullRequestDialog(
  BuildContext context, {
  required String currentBranch,
  required List<GitBranch> availableBranches,
}) {
  return Overlays.dialogFrom<CreatePullRequestResult>(
    context,
    route: DialogRouteSpec(
      title: AppLocalizations.of(context)!.createPullRequestDialogTitle,
    ),
    builder: (context) => CreatePullRequestDialog(
      currentBranch: currentBranch,
      availableBranches: availableBranches,
    ),
  );
}
