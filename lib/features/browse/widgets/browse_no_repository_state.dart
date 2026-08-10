import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// No repository state for browse screen
class BrowseNoRepositoryState extends StatelessWidget {
  const BrowseNoRepositoryState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The facade rather than a hand-built copy of it (#430). The `64` and the
    // on-surface-variant role beside it were one decision and it is the
    // member's: `EmptyStateSpec` takes an icon, a headline, a sentence and the
    // ways out, and NO size, so a size at a call site is a leak by
    // construction and the colour paired with it goes the same way.
    //
    // `EmptyStateWidget` directly rather than the `NoRepositoryEmptyState`
    // wrapper beside it, which says this same thing with the same mark: the
    // wrapper names `folderOpen` for the caller, and a screen that stops
    // naming its own mark drops out of the glyph census that guards this
    // conversion (test/features/icon_vocabulary_glyph_identity_test.dart).
    // The mark is what this state is, so it stays said here.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.folderOpen,
      title: l10n.noRepositoryOpen,
      message: l10n.openRepositoryToBrowseFiles,
    );
  }
}
