import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/git/destructive_action.dart';
import '../../generated/app_localizations.dart';
import '../components/base_button.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';

/// The single gate every destructive Git action passes through, so a
/// destructive action can never reach git without a confirmation the user can
/// recognise. Returns true when the user confirmed (or has silenced the
/// recoverable tiers), false when they cancelled or dismissed.
///
/// The prompt's strength scales with [DestructiveAction.tier]:
/// - the two recoverable local tiers are silenced when the user turns the
///   "confirm destructive actions" setting off, and otherwise use the softer
///   confirmation styling;
/// - the permanent and remote-affecting tiers always ask and use the red
///   destructive styling, because there is no reflog or local copy to recover
///   from and — for the remote tier — the loss is not even the user's own.
///
/// [title], [message] and [confirmLabel] stay with the caller so each action
/// keeps its own localized, context-specific wording (the commit hash, the
/// branch name, the file path); the tier alone lives in [DestructiveAction].
Future<bool> confirmDestructive({
  required BuildContext context,
  required WidgetRef ref,
  required DestructiveAction action,
  required String title,
  required String message,
  String? confirmLabel,
  IconData? icon,
}) async {
  final tier = action.tier;
  if (tier.isSilenceable && !ref.read(confirmDestructiveActionsProvider)) {
    return true;
  }

  final l10n = AppLocalizations.of(context)!;
  final destructive = tier.usesDestructiveStyle;
  final confirmed = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      icon: icon,
      variant: destructive
          ? DialogVariant.destructive
          : DialogVariant.confirmation,
      content: BodyMediumLabel(message),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: confirmLabel ?? l10n.confirm,
          variant: destructive ? ButtonVariant.danger : ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
