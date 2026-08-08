import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Error state for stashes screen when loading fails
class StashesErrorState extends StatelessWidget {
  final Object error;

  const StashesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The facade's shape, and it still cannot adopt `EmptyStateWidget`
          // (#430), for the reason changes_error_state.dart records: the
          // facade paints its hero in the supporting foreground and carries
          // no tone slot, so adopting it would turn this red mark grey and
          // erase the only thing distinguishing a failure from an ordinary
          // empty pane. That is a change of appearance, not a rename, so it
          // is reported rather than made; the size is stranded with the
          // colour, and the error role is not rounded onto `Tone.danger` -
          // danger means "this destroys something you cannot get back",
          // which a failed stash listing is not saying.
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.errorLoadingStashes,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            error.toString(),
            role: TextRole.detail,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
