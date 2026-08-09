import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, SuggestItem, TextRole, Tone;
import 'package:timeago/timeago.dart' as timeago;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
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
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleButton(
                            context,
                            label: l10n.localTab,
                            isSelected: !_showRemoteBranchesForSource,
                            onTap: () {
                              setState(() {
                                _showRemoteBranchesForSource = false;
                                _resetSourceBranchSelection();
                              });
                            },
                          ),
                          _buildToggleButton(
                            context,
                            label: l10n.remoteTab,
                            isSelected: _showRemoteBranchesForSource,
                            onTap: () {
                              setState(() {
                                _showRemoteBranchesForSource = true;
                                _resetSourceBranchSelection();
                              });
                            },
                          ),
                        ],
                      ),
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
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleButton(
                            context,
                            label: l10n.localTab,
                            isSelected: !_showRemoteBranchesForTarget,
                            onTap: () {
                              setState(() {
                                _showRemoteBranchesForTarget = false;
                                _resetBranchSelection();
                              });
                            },
                          ),
                          _buildToggleButton(
                            context,
                            label: l10n.remoteTab,
                            isSelected: _showRemoteBranchesForTarget,
                            onTap: () {
                              setState(() {
                                _showRemoteBranchesForTarget = true;
                                _resetBranchSelection();
                              });
                            },
                          ),
                        ],
                      ),
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
            CheckboxListTile(
              value: _isDraft,
              onChanged: (value) {
                setState(() {
                  _isDraft = value ?? false;
                });
              },
              title: Text(l10n.createAsDraftLabel),
              subtitle: Text(l10n.draftPRDescription),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const BaseGap(Proximity.related),

            // Info message
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              // The callout paints its own fill and states the paired
              // foreground once, here.
              child: BaseInset(
                all: Inset.normal,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.info,
                        size: AppTheme.iconS,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const BaseGap(Proximity.grouped),
                      Expanded(
                        child: BaseLabel(
                          l10n.prInfoMessage,
                          role: TextRole.detail,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        // Tone.onAccent when selected, because THIS toggle paints its own
        // accent fill three lines up - the exact case the tone's doc names.
        // Both the hand-painted fill and the tone leave together when the
        // toggle becomes a proper choice control. The bold-when-selected is
        // gone: selection is already stated by the fill, and weight was the
        // same fact said twice.
        child: BaseLabel(
          label,
          role: TextRole.control,
          tone: isSelected ? Tone.onAccent : Tone.muted,
        ),
      ),
    );
  }
}

/// Show create pull request dialog
Future<CreatePullRequestResult?> showCreatePullRequestDialog(
  BuildContext context, {
  required String currentBranch,
  required List<GitBranch> availableBranches,
}) {
  return showDialog<CreatePullRequestResult>(
    context: context,
    builder: (context) => CreatePullRequestDialog(
      currentBranch: currentBranch,
      availableBranches: availableBranches,
    ),
  );
}
