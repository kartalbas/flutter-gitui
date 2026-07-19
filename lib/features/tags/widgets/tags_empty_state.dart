import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// Empty state for tags screen when no tags exist
class TagsEmptyState extends StatelessWidget {
  const TagsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.tag,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.noTags),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            'Tags mark specific points in your repository history.\nCreate tags from commits in the History view.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
