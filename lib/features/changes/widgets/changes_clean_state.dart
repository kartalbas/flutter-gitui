import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Clean working directory state for changes screen
class ChangesCleanState extends StatelessWidget {
  const ChangesCleanState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.checkCircle,
            size: 64,
            color: context.gitColors.added,
          ),
          // The hero glyph and the headline are two groups inside one region:
          // `separate`, Material's 24.
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.workingDirectoryClean,
            role: TextRole.pageTitle,
          ),
          // The headline and the sentence explaining it are two parts of one
          // statement: `related`, Material's 8.
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.noChangesToCommit,
            role: TextRole.body,
          ),
        ],
      ),
    );
  }
}
