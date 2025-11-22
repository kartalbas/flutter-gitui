import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Dialog to confirm clearing all stashes
class ClearAllStashesDialog extends StatelessWidget {
  const ClearAllStashesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.clearAllStashesDialog,
      icon: PhosphorIconsRegular.warningCircle,
      variant: DialogVariant.destructive,
      content: BodyMediumLabel(
        l10n.clearAllStashesConfirm,
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.clearAll,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
