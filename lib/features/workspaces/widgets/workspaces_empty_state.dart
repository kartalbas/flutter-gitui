import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state for workspaces screen when no workspaces exist
class WorkspacesEmptyState extends StatelessWidget {
  const WorkspacesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    // The hand-rolled Column of {64 px glyph, headline, explanation} is gone,
    // and the glyph SIZE went with it (#430). `EmptyStateSpec` takes
    // icon/title/message and no size at all, so a member that accepts no size
    // owns it - which makes a size written here a leak by construction rather
    // than a value to translate into a scale word. This widget therefore
    // states only what the empty state SAYS and lets the facade that becomes
    // `surfaces.emptyState` decide how large its mark is and how far the
    // words sit from the region's edges.
    //
    // The mark's colour moves with the size: this state painted its glyph in
    // Material's accent role, and the member draws every empty state's mark in
    // the supporting foreground instead, so this one stops being the single
    // empty state in the application that shouted.
    return EmptyStateWidget(
      icon: PhosphorIconsBold.folder,
      title: AppLocalizations.of(context)!.noWorkspacesYet,
      message: AppLocalizations.of(context)!.createWorkspaceToOrganize,
    );
  }
}
