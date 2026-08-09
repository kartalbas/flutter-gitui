import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Error state for branches screen when loading fails
class BranchesErrorState extends StatelessWidget {
  final Object error;

  const BranchesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Not the empty-state facade (#430). The hero carries a tone now
          // (#431) and `EmptyStateSpec.tone` settles what to say with it, so
          // the mark's COLOUR no longer blocks this - its SIZE and its SHAPE
          // still do, and this is the only one of the four screen-level error
          // states where they do. Its three siblings (tags, stashes, changes)
          // draw a 64 dp hero over a headline and a sentence, which is the
          // facade's own shape and is what let them adopt it. This one drifted
          // to a 48 dp mark over a single headline that folds the error into
          // its own words, with no sentence under it: adopting would hand the
          // `48` to a member that draws its hero at 64 and add the member's
          // empty second line beneath, both changes of appearance rather than
          // renames - the same pair blame_dialog.dart and
          // unified_diff_dialog.dart are reported for. Reported instead: this
          // converts when the facade can say a one-statement shape, and the
          // colour leaves with the size it is stranded to, because `BaseIcon`
          // tops out at 24 dp and rounding a 48 dp hero onto it is #426.
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          // The glyph and the headline are members of one statement: `grouped`,
          // which Material answers with the 16 pixels this line used to name.
          const BaseGap(Proximity.grouped),
          // The error state's headline, at the same rung as every other one.
          BaseLabel(
            AppLocalizations.of(
              context,
            )!.errorLoadingBranches(error.toString()),
            role: TextRole.pageTitle,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
