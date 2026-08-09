import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Error state for tags screen
class TagsErrorState extends StatelessWidget {
  final Object error;

  const TagsErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // The facade rather than a hand-built copy of it (#430). This column was
    // already shaped exactly as the facade draws - hero, headline, sentence -
    // and was held back by one fact: the hero had no tone slot, so adopting
    // it would have turned a red failure mark grey and erased the only thing
    // distinguishing a failure from an ordinary empty pane. The hero carries
    // a tone now (#431), and `EmptyStateSpec.tone` settles what to say with
    // it: "a state standing in for a FAILURE says Tone.danger". So the mark
    // stays the failure colour because the state SAYS failure, not because
    // this widget picked the scheme's error role. The `64` and the sentence's
    // treatment go to the member with it, the way reflog_dialog's did.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorLoadingTags,
      message: error.toString(),
      tone: Tone.danger,
    );
  }
}
