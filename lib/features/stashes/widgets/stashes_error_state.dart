import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Error state for stashes screen when loading fails
class StashesErrorState extends StatelessWidget {
  final Object error;

  const StashesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // The facade rather than a hand-built copy of it (#430), for the reason
    // tags_error_state.dart records: this column was already the facade's
    // shape - hero, headline, sentence - and the hero's missing tone slot was
    // the single fact holding it back, because adopting would have turned a
    // red failure mark grey. `EmptyStateSpec.tone` says a state standing in
    // for a FAILURE says `Tone.danger` (#431), so the mark keeps its colour
    // by stating a meaning rather than by naming the scheme's error role.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorLoadingStashes,
      message: error.toString(),
      tone: Tone.danger,
    );
  }
}
