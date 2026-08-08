import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, TextRole;

import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../generated/app_localizations.dart';

/// Dialog warning about uncommitted changes before branch switch
class UncommittedChangesDialog extends StatelessWidget {
  final int changeCount;

  const UncommittedChangesDialog({super.key, required this.changeCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pluralForm = changeCount > 1 ? 's' : '';

    return BaseDialog(
      title: l10n.uncommittedChanges,
      icon: IconRole.warning,
      variant: DialogVariant.confirmation,
      maxWidth: 400,
      onSubmit: () => Navigator.pop(context, true),
      content: BaseLabel(
        l10n.youHaveUncommittedChanges(changeCount, pluralForm),
        role: TextRole.body,
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.pop(context, false),
        ),
        DialogAction(
          label: l10n.switchAnyway,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
