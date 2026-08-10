import 'package:flutter/widgets.dart';
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
          // An empty state's hero glyph stays a raw `Icon`: `ControlScale`'s
          // largest rung is the ordinary size of a control's mark, and the
          // artwork that fills an empty region is a different order of thing.
          // Naming the nearest rung would shrink this to a toolbar glyph, so
          // the literal stays until the vocabulary has the word - and the
          // colour stays with it, because a tone can only be said through
          // `BaseIcon`, which would drag the missing rung in behind it.
          Icon(
            PhosphorIconsRegular.checkCircle,
            size: 64,
            color: context.gitColors.added,
          ),
          // The hero glyph and the headline are two groups inside one region:
          // `separate`.
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.workingDirectoryClean,
            role: TextRole.pageTitle,
          ),
          // The headline and the sentence explaining it are two parts of one
          // statement: `related`.
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
