import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/branch.dart';

/// Dialog to confirm merging a branch into the current branch
class MergeBranchDialog extends StatelessWidget {
  final GitBranch branch;

  const MergeBranchDialog({
    super.key,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.mergeBranchDialog,
      icon: PhosphorIconsRegular.gitMerge,
      variant: DialogVariant.confirmation,
      content: BodyMediumLabel(
        l10n.mergeBranchConfirm(branch.shortName, branch.shortName, 'current'),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.merge,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
