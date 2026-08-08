import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

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

    // The banner's margin is the distance between the banner and the screen
    // around it - an inset owed by what CONTAINS the banner, not by the banner
    // itself - so it is stated as an inset around the whole surface rather
    // than as a fourth number inside it.
    return BaseInset(
      all: Inset.normal,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withAlpha(77),
          ),
        ),
        // The banner paints its own fill, so it owes its content the foreground
        // that pairs with it — stated once, here, rather than repeated by each
        // of the three labels inside. Without this the labels would inherit the
        // page's `onSurface` and paint it over a `primaryContainer` fill, which
        // is the 4.13 : 1 defect this repository has already shipped once.
        child: BaseInset(
          all: Inset.normal,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.gitDiff,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const BaseGap(Proximity.grouped),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel('Sync Status', role: TextRole.sectionTitle),
                      const BaseGap(Proximity.hairline),
                      if (localOnlyCount > 0)
                        BaseLabel(
                          '$localOnlyCount tag${localOnlyCount == 1 ? '' : 's'} not pushed to remote',
                          role: TextRole.detail,
                        ),
                      if (remoteOnlyCount > 0)
                        BaseLabel(
                          '$remoteOnlyCount tag${remoteOnlyCount == 1 ? '' : 's'} available to fetch',
                          role: TextRole.detail,
                        ),
                    ],
                  ),
                ),
                if (localOnlyCount > 0)
                  BaseButton(
                    onPressed: onPushAll,
                    leadingIcon: IconRole.upload,
                    label: AppLocalizations.of(context)!.pushAll,
                    variant: ButtonVariant.primary,
                    size: ButtonSize.small,
                  ),
                if (remoteOnlyCount > 0 && localOnlyCount > 0)
                  // Sibling actions in one run are members of one group:
                  // `grouped`, the vocabulary's own exemplar for a run of
                  // actions.
                  const BaseGap(Proximity.grouped),
                if (remoteOnlyCount > 0)
                  BaseButton(
                    onPressed: onFetchAll,
                    leadingIcon: IconRole.downloadSimple,
                    label: AppLocalizations.of(context)!.fetchAll,
                    variant: ButtonVariant.primary,
                    size: ButtonSize.small,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
