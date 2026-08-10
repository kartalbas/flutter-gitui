import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for confirming tag checkout
class CheckoutTagDialog extends StatelessWidget {
  final String tagName;

  const CheckoutTagDialog({super.key, required this.tagName});

  /// Asks the user, on the skin's own dialog route.
  ///
  /// The frame this dialog states — its title, its mark and its two ways out —
  /// is the same on every build and every callback only pops, so the whole
  /// dialog can be stated before it exists. That is what lets it reach
  /// `Overlays.dialog` instead of Material's `showDialog`: the route becomes
  /// the skin's, and nothing about the dialog changes.
  static Future<bool?> show(BuildContext context, {required String tagName}) =>
      BaseDialog.show<bool>(
        context: context,
        dialog: _dialog(context, tagName),
      );

  @override
  Widget build(BuildContext context) => _dialog(context, tagName);

  static BaseDialog _dialog(BuildContext context, String tagName) {
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
