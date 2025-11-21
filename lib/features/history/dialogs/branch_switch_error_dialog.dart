import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
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
      icon: PhosphorIconsRegular.xCircle,
      variant: DialogVariant.destructive,
      maxWidth: 400,
      content: BodyMediumLabel(
        l10n.failedToSwitchToBranch(branchName, error),
      ),
      actions: [
        BaseButton(
          label: l10n.ok,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
