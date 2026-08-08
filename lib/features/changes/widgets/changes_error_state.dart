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
          // The error state's hero glyph stays a raw `Icon`, and for two
          // reasons rather than one. Its size has no rung: `ControlScale`'s
          // largest step is the ordinary size of a control's mark, and the
          // artwork filling an empty region is a different order of thing.
          // Its colour has no word either - `Tone.danger` is "this destroys
          // something you cannot get back", which is not what a failed status
          // read is saying. Neither is rounded to its nearest neighbour.
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
