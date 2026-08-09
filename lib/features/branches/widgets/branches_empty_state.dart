import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state for branches when no branches exist
class BranchesEmptyState extends StatelessWidget {
  final bool isLocal;

  const BranchesEmptyState({super.key, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    // The facade rather than a hand-built copy of it (#430). The colour was
    // never the thing holding this back on its own: `EmptyStateWidget` already
    // said "there is nothing here yet" in the supporting foreground, which is
    // what this column spelled out. What held it back was the SIZE, and the
    // size is not this file's to keep - `_heroGlyph` records that a member
    // accepting no size OWNS the size, so a `48` written at a call site is the
    // leak by construction rather than a local decision worth preserving. The
    // read leaves with it: a `Tone` reaches a mark only through `BaseIcon`,
    // whose largest rung is 24 dp, so converting the colour without the member
    // would have shrunk the hero - #426 verbatim.
    //
    // Three deltas ride along with the member, the same three the eleven
    // earlier adopters took: the hero grows 48 -> 64 dp (which is what every
    // other empty state in the application already draws, so this removes a
    // disagreement rather than introducing one), the column sits inside the
    // member's roomy inset, and the mark-to-headline gap becomes the member's
    // `separate` where this copy said `grouped`.
    //
    // The explaining sentence is empty because this state has never had one
    // and inventing words is not a rename; `ErrorState` ships the same
    // construction for the same reason.
    return EmptyStateWidget(
      icon: isLocal ? PhosphorIconsRegular.folder : PhosphorIconsRegular.cloud,
      title: isLocal
          ? AppLocalizations.of(context)!.noLocalBranches
          : AppLocalizations.of(context)!.noRemoteBranches,
      message: '',
    );
  }
}
