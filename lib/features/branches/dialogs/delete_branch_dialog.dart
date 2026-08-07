import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/git/models/branch.dart';

/// Result from delete branch dialog
enum DeleteBranchResult { cancel, delete, forceDelete }

/// Dialog to confirm deleting a local branch.
///
/// Remote branches never reach this dialog: deleting a ref off the server is
/// a remote-permanent action, so the call sites route it through
/// `confirmDestructive`'s type-to-confirm gate instead. Protected branches
/// (local or remote) still land here to get the explanatory refusal.
class DeleteBranchDialog extends StatefulWidget {
  final GitBranch branch;

  const DeleteBranchDialog({super.key, required this.branch});

  @override
  State<DeleteBranchDialog> createState() => _DeleteBranchDialogState();
}

class _DeleteBranchDialogState extends State<DeleteBranchDialog> {
  // Force delete (git branch -D) discards unmerged commits, recoverable only
  // via reflog, so it stays behind an explicit opt-in instead of sitting next
  // to the safe delete as an equally reachable one-click action.
  bool _force = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final branch = widget.branch;

    // Don't allow deleting protected branches
    if (branch.isProtected) {
      return BaseDialog(
        title: l10n.deleteBranchDialog,
        icon: PhosphorIconsRegular.lock,
        variant: DialogVariant.normal,
        onSubmit: () => Navigator.of(context).pop(),
        content: BodyMediumLabel(
          'Cannot delete protected branch "${branch.shortName}". This branch is protected from deletion.',
        ),
      );
    }

    return BaseDialog(
      title: l10n.deleteBranchDialog,
      icon: PhosphorIconsRegular.warning,
      variant: DialogVariant.destructive,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyMediumLabel(l10n.deleteBranchConfirm(branch.shortName)),
          const SizedBox(height: AppTheme.paddingS),
          CheckboxListTile(
            value: _force,
            onChanged: (value) => setState(() => _force = value ?? false),
            title: BodyMediumLabel(l10n.forceDelete),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_force)
            BodySmallLabel(
              l10n.forceDeleteWarning,
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(DeleteBranchResult.cancel),
        ),
        DialogAction(
          label: _force ? l10n.forceDelete : l10n.delete,
          role: DialogActionRole.destructive,
          onPressed: () => Navigator.of(context).pop(
            _force ? DeleteBranchResult.forceDelete : DeleteBranchResult.delete,
          ),
        ),
      ],
    );
  }
}
