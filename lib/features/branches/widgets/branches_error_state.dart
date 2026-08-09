import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Error state for branches screen when loading fails
class BranchesErrorState extends StatelessWidget {
  final Object error;

  const BranchesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // The facade rather than a hand-built copy of it (#430), and the last of
    // the four screen error states to adopt. Its three siblings (changes,
    // stashes, tags) went at #431, when the hero learned to say `Tone.danger`
    // and a failure stopped being dressed as an ordinary empty pane. This one
    // stayed behind on its SIZE alone: it drifted to a 48 dp mark where they
    // drew 64.
    //
    // That is not a difference worth forking a shared member over, and it is
    // not this file's decision to hold: `EmptyStateWidget._heroGlyph` records
    // that a member accepting no size owns the size, so the `48` here was the
    // leak rather than the intent. The read leaves with it - a `Tone` reaches
    // a mark only through `BaseIcon`, whose largest rung is 24 dp, so
    // converting the colour alone would have shrunk the hero, which is #426.
    //
    // Deltas, stated rather than discovered later: the hero grows 48 -> 64 dp
    // (matching its three siblings), the column takes the member's roomy
    // inset, and the mark-to-headline gap becomes the member's `separate`. The
    // words do not move - `errorLoadingBranches` folds the error into one
    // headline, so it stays the headline and the explaining sentence is empty,
    // the construction `ErrorState` already ships.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(
        context,
      )!.errorLoadingBranches(error.toString()),
      message: '',
      tone: Tone.danger,
    );
  }
}
