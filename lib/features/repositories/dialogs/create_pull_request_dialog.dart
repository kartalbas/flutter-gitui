import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_dropdown.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../generated/app_localizations.dart';
import '../../../core/git/models/branch.dart';

/// Result of the create pull request dialog
class CreatePullRequestResult {
  final String title;
  final String description;
  final String baseBranch;
  final bool draft;

  const CreatePullRequestResult({
    required this.title,
    required this.description,
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
  State<CreatePullRequestDialog> createState() => _CreatePullRequestDialogState();
}

class _CreatePullRequestDialogState extends State<CreatePullRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late GitBranch _selectedBaseBranch;
  bool _isDraft = false;
  bool _showRemoteBranchesForTarget = false;

  @override
  void initState() {
    super.initState();

    // Try to detect main branch from available branches
    final mainBranches = ['main', 'master', 'develop', 'development'];
    _selectedBaseBranch = widget.availableBranches.firstWhere(
      (branch) => mainBranches.contains(branch.name) && branch.name != widget.currentBranch,
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

    // Filter branches based on remote flag for target/base branch
    // For PRs, both local and remote branches make sense as targets
    var filteredBranches = _showRemoteBranchesForTarget
        ? widget.availableBranches.toList()
        : widget.availableBranches.where((b) => !b.isRemote).toList();

    // Sort by last commit date (newest first), with null dates at the end
    filteredBranches.sort((a, b) {
      if (a.lastCommitDate == null && b.lastCommitDate == null) {
        return a.name.compareTo(b.name);
      }
      if (a.lastCommitDate == null) return 1;
      if (b.lastCommitDate == null) return -1;
      return b.lastCommitDate!.compareTo(a.lastCommitDate!);
    });

    // Filter out current branch
    filteredBranches = filteredBranches
        .where((branch) => branch.name != widget.currentBranch)
        .toList();

    return BaseDialog(
      title: l10n.createPullRequestDialogTitle,
      icon: PhosphorIconsBold.gitPullRequest,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current branch info
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsBold.gitBranch,
                    size: AppTheme.iconM,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BodySmallLabel(
                          l10n.sourceBranchLabel,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        TitleSmallLabel(
                          widget.currentBranch,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Base branch selection with search
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchableBaseDropdown<GitBranch>(
                    value: _selectedBaseBranch,
                    labelText: l10n.targetBranchLabel,
                    hintText: l10n.selectTargetBranch,
                    searchHintText: l10n.searchBranches,
                    prefixIcon: PhosphorIconsRegular.gitBranch,
                    displayStringForItem: (branch) => branch.name,
                    items: filteredBranches.map((branch) {
                      final lastCommitText = branch.lastCommitDate != null
                          ? timeago.format(branch.lastCommitDate!, locale: 'en_short')
                          : null;
                      return SearchableDropdownItem<GitBranch>.simple(
                        value: branch,
                        label: branch.name,
                        subtitle: lastCommitText,
                        icon: branch.isRemote
                            ? PhosphorIconsRegular.cloud
                            : PhosphorIconsRegular.gitBranch,
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBaseBranch = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return l10n.selectTargetBranch;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),
                // Toggle switch for target branch
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: AppTheme.paddingL + AppTheme.paddingS),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

            const SizedBox(height: AppTheme.paddingL),

            // PR Title
            LabelLargeLabel(
              l10n.pullRequestTitleLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BaseTextField(
              controller: _titleController,
              hintText: l10n.enterPRTitle,
              prefixIcon: PhosphorIconsRegular.textT,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterPRTitleValidation;
                }
                return null;
              },
              autofocus: true,
            ),

            const SizedBox(height: AppTheme.paddingL),

            // PR Description
            LabelLargeLabel(
              l10n.descriptionLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BaseTextField(
              controller: _descriptionController,
              hintText: l10n.enterPRDescription,
              prefixIcon: PhosphorIconsRegular.textAlignLeft,
              maxLines: 5,
            ),

            const SizedBox(height: AppTheme.paddingL),

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

            const SizedBox(height: AppTheme.paddingS),

            // Info message
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: BodySmallLabel(
                      l10n.prInfoMessage,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: l10n.createPRButton,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsBold.gitPullRequest,
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
        baseBranch: _selectedBaseBranch.name,
        draft: _isDraft,
      );
      Navigator.of(context).pop(result);
    }
  }

  void _resetBranchSelection() {
    final mainBranches = ['main', 'master', 'develop', 'development'];
    final newFilteredBranches = _showRemoteBranchesForTarget
        ? widget.availableBranches
        : widget.availableBranches.where((b) => !b.isRemote).toList();
    _selectedBaseBranch = newFilteredBranches.firstWhere(
      (branch) => mainBranches.contains(branch.name) && branch.name != widget.currentBranch,
      orElse: () => newFilteredBranches.firstWhere(
        (branch) => branch.name != widget.currentBranch,
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
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: MenuItemLabel(
          label,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
