import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../generated/app_localizations.dart';

/// Dialog warning about uncommitted changes before branch switch
class UncommittedChangesDialog extends StatelessWidget {
  final int changeCount;

  const UncommittedChangesDialog({
    super.key,
    required this.changeCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pluralForm = changeCount > 1 ? 's' : '';

    return BaseDialog(
      title: l10n.uncommittedChanges,
      icon: PhosphorIconsRegular.warning,
      variant: DialogVariant.confirmation,
      maxWidth: 400,
      content: BodyMediumLabel(
        l10n.youHaveUncommittedChanges(changeCount, pluralForm),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.pop(context, false),
        ),
        BaseButton(
          label: l10n.switchAnyway,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
