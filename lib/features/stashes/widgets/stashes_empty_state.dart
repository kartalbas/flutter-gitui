import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state for stashes screen when no stashes exist
class StashesEmptyState extends StatelessWidget {
  final VoidCallback onCreateStash;

  const StashesEmptyState({super.key, required this.onCreateStash});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The empty-state hero with its way out. The action was already a
    // `BaseButton` at the primary emphasis, which is exactly what the member
    // builds from `actionLabel`/`actionIcon`, so handing it over changes no
    // pixels and takes the mark's size and colour out of this file with it -
    // `EmptyStateSpec` accepts neither, which is what makes a size written
    // here a leak by construction.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.package,
      title: l10n.noStashes,
      message: l10n.createStashToSaveWorkInProgress,
      actionLabel: l10n.createStash,
      actionIcon: IconRole.floppyDisk,
      onActionPressed: onCreateStash,
    );
  }
}
