import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../generated/app_localizations.dart';

/// Dialog showing error when branch switch fails
class BranchSwitchErrorDialog extends StatelessWidget {
  final String branchName;
  final String error;

  const BranchSwitchErrorDialog({
    super.key,
    required this.branchName,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.branchSwitchFailed,
      icon: IconRole.xCircle,
      variant: DialogVariant.destructive,
      maxWidth: 400,
      // Red styling for attention only; the single action is OK, so Enter
      // dismisses like any informational dialog.
      onSubmit: () => Navigator.pop(context),
      content: BodyMediumLabel(l10n.failedToSwitchToBranch(branchName, error)),
      actions: [
        DialogAction(
          label: l10n.ok,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
