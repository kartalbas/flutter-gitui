import 'package:flutter/material.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// No repository state for tags screen
class TagsNoRepositoryState extends StatelessWidget {
  const TagsNoRepositoryState({super.key});

  @override
  Widget build(BuildContext context) {
    // "There is no repository open" is a state the application already has one
    // member for, and this screen was drawing its own copy of it - same glyph,
    // same headline, its own gaps and its own hard-coded mark colour. Saying it
    // once through the shared state is what stops the two drifting apart, and
    // it is what removes the size and the colour of the mark from a feature
    // file: `EmptyStateSpec` carries neither.
    return NoRepositoryEmptyState(
      contextMessage: AppLocalizations.of(context)!.openRepositoryToManageTags,
    );
  }
}
