import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show DialogExtent, IconRole, TextRole;

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
      // A sentence and one answer: the `alert` extent by the vocabulary's own
      // words, and 400 under Material - the width this dialog already had.
      extent: DialogExtent.alert,
      // Red styling for attention only; the single action is OK, so Enter
      // dismisses like any informational dialog.
      onSubmit: () => Navigator.pop(context),
      content: BaseLabel(
        l10n.failedToSwitchToBranch(branchName, error),
        role: TextRole.body,
      ),
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
