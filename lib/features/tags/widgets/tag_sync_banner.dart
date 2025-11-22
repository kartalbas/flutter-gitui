import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Banner widget showing tag sync status with local/remote repositories
class TagSyncBanner extends StatelessWidget {
  final int localOnlyCount;
  final int remoteOnlyCount;
  final VoidCallback onPushAll;
  final VoidCallback onFetchAll;

  const TagSyncBanner({
    super.key,
    required this.localOnlyCount,
    required this.remoteOnlyCount,
    required this.onPushAll,
    required this.onFetchAll,
  });

  @override
  Widget build(BuildContext context) {
    if (localOnlyCount == 0 && remoteOnlyCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      margin: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(77),
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.gitDiff,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleSmallLabel(
                  'Sync Status',
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: AppTheme.paddingXS),
                if (localOnlyCount > 0)
                  BodySmallLabel(
                    '$localOnlyCount tag${localOnlyCount == 1 ? '' : 's'} not pushed to remote',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                if (remoteOnlyCount > 0)
                  BodySmallLabel(
                    '$remoteOnlyCount tag${remoteOnlyCount == 1 ? '' : 's'} available to fetch',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
              ],
            ),
          ),
          if (localOnlyCount > 0)
            BaseButton(
              onPressed: onPushAll,
              leadingIcon: PhosphorIconsRegular.upload,
              label: AppLocalizations.of(context)!.pushAll,
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
            ),
          if (remoteOnlyCount > 0 && localOnlyCount > 0)
            const SizedBox(width: AppTheme.paddingS),
          if (remoteOnlyCount > 0)
            BaseButton(
              onPressed: onFetchAll,
              leadingIcon: PhosphorIconsRegular.downloadSimple,
              label: AppLocalizations.of(context)!.fetchAll,
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
            ),
        ],
      ),
    );
  }
}
