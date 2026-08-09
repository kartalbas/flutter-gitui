import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Error state for changes screen when status loading fails
class ChangesErrorState extends StatelessWidget {
  final Object error;

  const ChangesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // The facade rather than a hand-built copy of it (#430). This was the
    // file that first recorded why the copy existed: the facade painted its
    // hero in the supporting foreground and carried no tone slot, so adopting
    // it would have greyed out a failure. Both halves of that objection are
    // answered now. The hero takes a tone (#431), and `EmptyStateSpec.tone`
    // decides what the tone says - "a state standing in for a FAILURE says
    // Tone.danger" - which is the contract making the call this file declined
    // to make on its own when the only argument available was the definition
    // of `Tone.danger` read in isolation. The size was never a separate
    // decision from the colour, and it leaves with it.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorLoadingStatus,
      message: error.toString(),
      tone: Tone.danger,
    );
  }
}
