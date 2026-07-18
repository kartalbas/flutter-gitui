import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../core/git/models/stash.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Dialog to confirm dropping a stash
class DropStashDialog extends StatelessWidget {
  final GitStash stash;

  const DropStashDialog({
    super.key,
    required this.stash,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.dropStashDialog,
      icon: PhosphorIconsRegular.warningCircle,
      variant: DialogVariant.destructive,
      content: BodyMediumLabel(
        l10n.dropStashConfirm(stash.ref),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.drop,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
