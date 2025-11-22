import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../core/git/models/remote.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../components/base_label.dart';

/// Dialog to confirm pruning a remote
class PruneRemoteDialog extends StatelessWidget {
  final GitRemote remote;

  const PruneRemoteDialog({
    super.key,
    required this.remote,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BaseDialog(
      title: l10n.pruneRemote(remote.name),
      icon: PhosphorIconsRegular.broom,
      variant: DialogVariant.confirmation,
      content: BodyMediumLabel(l10n.pruneRemoteConfirm(remote.name)),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.prune,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
