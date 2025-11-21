import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for confirming tag checkout
class CheckoutTagDialog extends StatelessWidget {
  final String tagName;

  const CheckoutTagDialog({
    super.key,
    required this.tagName,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final confirmMessage = loc.checkoutTagConfirm(tagName);

    return BaseDialog(
      title: loc.checkoutTagDialog,
      icon: PhosphorIconsRegular.gitBranch,
      variant: DialogVariant.confirmation,
      content: BodyMediumLabel(confirmMessage),
      actions: [
        BaseButton(
          label: loc.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: loc.checkout,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
