import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../generated/app_localizations.dart';

/// Dialog warning about force push consequences
class ForcePushDialog extends StatelessWidget {
  const ForcePushDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.pushRejected,
      icon: PhosphorIconsRegular.warningCircle,
      variant: DialogVariant.destructive,
      maxWidth: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitleSmallLabel(
            l10n.pushRejectedHistoryRewritten,
          ),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(l10n.needToForcePushChanges),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(
            l10n.forcePushWarningOverwriteRemote,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel('• ${l10n.forcePushOnlyIfAlone}'),
          BodySmallLabel('• ${l10n.forcePushOthersNeedReset}'),
          BodySmallLabel('• ${l10n.forcePushCannotBeEasilyUndone}'),
        ],
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.forcePush,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

