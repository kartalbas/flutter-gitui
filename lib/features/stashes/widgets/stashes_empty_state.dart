import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_layout.dart';

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
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.noStashes,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.createStashToSaveWorkInProgress,
            role: TextRole.body,
            align: TextAlign.center,
          ),
          const BaseGap(Proximity.separate),
          BaseButton(
            onPressed: onCreateStash,
            leadingIcon: IconRole.floppyDisk,
            label: AppLocalizations.of(context)!.createStash,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}
