import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Error state for changes screen when status loading fails
class ChangesErrorState extends StatelessWidget {
  final Object error;

  const ChangesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // This is the facade's shape - hero, headline, sentence - and it
          // still cannot adopt `EmptyStateWidget` (#430), for one reason: the
          // facade paints its hero in the supporting foreground and carries no
          // tone slot, so adopting it would turn this red mark grey and erase
          // the only thing distinguishing a failure from an ordinary empty
          // pane. That is a change of appearance, not a rename, so it is
          // reported rather than made. The size stays with it - `ControlScale`
          // tops out at the ordinary size of a CONTROL's mark, and this is a
          // region's artwork - and so does the error role below, which is not
          // rounded onto `Tone.danger`: danger means "this destroys something
          // you cannot get back", which a failed status read is not saying.
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          // The hero glyph and the headline are two groups inside one region:
          // `separate`.
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.errorLoadingStatus,
            role: TextRole.pageTitle,
          ),
          // The headline and the message explaining it are two parts of one
          // statement: `related`.
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
