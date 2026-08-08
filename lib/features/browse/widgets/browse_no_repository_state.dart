import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// No repository state for browse screen
class BrowseNoRepositoryState extends StatelessWidget {
  const BrowseNoRepositoryState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // An empty state's hero mark keeps its measure and its colour: no
          // rung of `ControlScale` reaches it, and a tone can only reach a
          // mark through `BaseIcon`. See history_empty_states.dart.
          Icon(
            PhosphorIconsRegular.folderOpen,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          // The hero glyph and the headline are two groups inside one region:
          // `separate`.
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.noRepositoryOpen,
            role: TextRole.pageTitle,
          ),
          // The headline and the sentence explaining it are two parts of one
          // statement: `related`.
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.openRepositoryToBrowseFiles,
            role: TextRole.body,
          ),
        ],
      ),
    );
  }
}
