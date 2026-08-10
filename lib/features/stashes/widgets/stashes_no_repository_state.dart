import 'package:flutter/widgets.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// No repository state for stashes screen
class StashesNoRepositoryState extends StatelessWidget {
  const StashesNoRepositoryState({super.key});

  @override
  Widget build(BuildContext context) {
    // The same shared "no repository is open" state the branches screen and
    // the repository screen already render; this file was a second copy of it
    // carrying its own mark colour. See `TagsNoRepositoryState` for why the
    // copy goes rather than being converted in place.
    return NoRepositoryEmptyState(
      contextMessage: AppLocalizations.of(
        context,
      )!.openRepositoryToManageStashes,
    );
  }
}
