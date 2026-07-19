import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/branch.dart';

/// Result from delete branch dialog
enum DeleteBranchResult {
  cancel,
  delete,
  forceDelete,
}

/// Dialog to confirm deleting a branch
class DeleteBranchDialog extends StatelessWidget {
  final GitBranch branch;

  const DeleteBranchDialog({
    super.key,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Don't allow deleting protected branches
    if (branch.isProtected) {
      return BaseDialog(
        title: l10n.deleteBranchDialog,
        icon: PhosphorIconsRegular.lock,
        variant: DialogVariant.normal,
        content: BodyMediumLabel(
          'Cannot delete protected branch "${branch.shortName}". This branch is protected from deletion.',
        ),
      );
    }

    // Remote branches are removed with `git push --delete`, which has no force
    // variant and performs no merge check, so offering "Force Delete" would
    // imply a distinction that does not exist on this path.
    if (branch.isRemote) {
      return BaseDialog(
        title: l10n.deleteBranchDialog,
        icon: PhosphorIconsRegular.warning,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(
          'Delete branch "${branch.branchNameWithoutRemote}" on remote "${branch.remoteName ?? ""}"?\n\n'
          'This deletes the branch on the server for everyone, including any unmerged commits. This action cannot be undone.',
        ),
        actions: [
          BaseButton(
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(DeleteBranchResult.cancel),
          ),
          BaseButton(
            label: l10n.delete,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(DeleteBranchResult.delete),
          ),
        ],
      );
    }

    return BaseDialog(
      title: l10n.deleteBranchDialog,
      icon: PhosphorIconsRegular.warning,
      variant: DialogVariant.destructive,
      content: BodyMediumLabel(
        l10n.deleteBranchConfirm(branch.shortName),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(DeleteBranchResult.cancel),
        ),
        BaseButton(
          label: l10n.delete,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(DeleteBranchResult.delete),
        ),
        Tooltip(
          message: l10n.forceDeleteWarning,
          child: BaseButton(
            label: l10n.forceDelete,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(DeleteBranchResult.forceDelete),
          ),
        ),
      ],
    );
  }
}
