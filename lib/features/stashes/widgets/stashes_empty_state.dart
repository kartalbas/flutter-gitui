import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';

/// Empty state for stashes screen when no stashes exist
class StashesEmptyState extends StatelessWidget {
  final VoidCallback onCreateStash;

  const StashesEmptyState({super.key, required this.onCreateStash});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.package,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.noStashes),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            AppLocalizations.of(context)!.createStashToSaveWorkInProgress,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseButton(
            onPressed: onCreateStash,
            leadingIcon: PhosphorIconsRegular.floppyDisk,
            label: AppLocalizations.of(context)!.createStash,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}
