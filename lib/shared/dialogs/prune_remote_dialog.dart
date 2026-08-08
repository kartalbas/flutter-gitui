import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';
import '../../core/git/models/remote.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';

/// Dialog to confirm pruning a remote
class PruneRemoteDialog extends StatelessWidget {
  final GitRemote remote;

  const PruneRemoteDialog({super.key, required this.remote});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BaseDialog(
      title: l10n.pruneRemote(remote.name),
      icon: IconRole.broom,
      variant: DialogVariant.confirmation,
      onSubmit: () => Navigator.of(context).pop(true),
      content: BodyMediumLabel(l10n.pruneRemoteConfirm(remote.name)),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: l10n.prune,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
