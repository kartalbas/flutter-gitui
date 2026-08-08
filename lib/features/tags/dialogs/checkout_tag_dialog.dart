import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for confirming tag checkout
class CheckoutTagDialog extends StatelessWidget {
  final String tagName;

  const CheckoutTagDialog({super.key, required this.tagName});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final confirmMessage = loc.checkoutTagConfirm(tagName);

    return BaseDialog(
      title: loc.checkoutTagDialog,
      icon: IconRole.gitBranch,
      variant: DialogVariant.confirmation,
      onSubmit: () => Navigator.of(context).pop(true),
      content: BaseLabel(confirmMessage, role: TextRole.body),
      actions: [
        DialogAction(
          label: loc.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: loc.checkout,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
