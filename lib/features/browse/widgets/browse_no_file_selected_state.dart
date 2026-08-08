import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// No file selected state for browse screen
class BrowseNoFileSelectedState extends StatelessWidget {
  const BrowseNoFileSelectedState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The hero mark's size and its colour are no longer written here, and that
    // is the whole point of adopting the facade (#430): `EmptyStateSpec` takes
    // an icon, a headline, a sentence and the ways out, and NO size - a member
    // that accepts no size owns the size, so the `64` and the
    // on-surface-variant role beside it were one leak by construction rather
    // than two numbers waiting for a rung. `ControlScale` never was the
    // answer: it asks how much room a CONTROL's mark is entitled to and tops
    // out at 24, so naming its loudest rung would have shrunk this glyph to a
    // third and turned an empty state into a blank one.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.file,
      title: l10n.noFileSelected,
      message: l10n.selectFileToViewHistoryOrPreview,
    );
  }
}
