import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state for tags screen when no tags exist
class TagsEmptyState extends StatelessWidget {
  const TagsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    // The empty-state hero, not a Column of its parts. The mark's size was the
    // one thing this screen could not say - no `ControlScale` rung reaches a
    // state's artwork - and the answer is that it is not the screen's to say:
    // `EmptyStateSpec` takes icon, title, message and actions and NO size, so
    // the member owns the measure and the colour of the mark together. This is
    // the facade that becomes `surfaces.emptyState`.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.tag,
      title: AppLocalizations.of(context)!.noTags,
      message:
          'Tags mark specific points in your repository history.\nCreate tags from commits in the History view.',
    );
  }
}
