import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/commit.dart';

/// Dialog for creating a branch from a commit in the history view.
///
/// Returns `{'branchName': String, 'checkout': bool}` like the tag variant,
/// so the caller runs the actual `git branch` through the shared commit
/// action sequence instead of the dialog invoking git itself.
class CreateBranchFromCommitDialog extends StatefulWidget {
  final GitCommit commit;

  const CreateBranchFromCommitDialog({super.key, required this.commit});

  @override
  State<CreateBranchFromCommitDialog> createState() =>
      _CreateBranchFromCommitDialogState();
}

class _CreateBranchFromCommitDialogState
    extends State<CreateBranchFromCommitDialog> {
  final _branchNameController = TextEditingController();
  bool _checkout = true;
  String? _errorMessage;

  @override
  void dispose() {
    _branchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.createBranchFromCommit,
      icon: IconRole.gitBranch,
      onSubmit: _createBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source commit info
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.gitCommit,
                  size: AppTheme.iconS,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(
                        l10n.sourceCommit,
                        role: TextRole.micro,
                        tone: Tone.muted,
                      ),
                      BaseLabel(
                        '${widget.commit.shortHash} '
                        '${widget.commit.shortSubject}',
                        role: TextRole.body,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingL),

          // Branch name input
          BaseTextField(
            controller: _branchNameController,
            label: l10n.branchName,
            hintText: l10n.branchNameHint,
            prefixIcon: IconRole.gitBranch,
            autofocus: true,
            errorText: _errorMessage,
            onChanged: (value) {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Checkout option
          CheckboxListTile(
            value: _checkout,
            onChanged: (value) {
              setState(() {
                _checkout = value ?? true;
              });
            },
            title: BaseLabel(
              l10n.checkoutBranchAfterCreation,
              role: TextRole.body,
            ),
            subtitle: BaseLabel(
              l10n.checkoutBranchAfterCreationHint,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.createBranch,
          role: DialogActionRole.affirmative,
          icon: IconRole.gitBranch,
          onPressed: _createBranch,
        ),
      ],
    );
  }

  void _createBranch() {
    final branchName = _branchNameController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (branchName.isEmpty) {
      setState(() {
        _errorMessage = l10n.branchNameRequired;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop({'branchName': branchName, 'checkout': _checkout});
  }
}
