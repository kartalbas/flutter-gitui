import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// No repository state for tags screen
class TagsNoRepositoryState extends StatelessWidget {
  const TagsNoRepositoryState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.folderOpen,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(
            AppLocalizations.of(context)!.noRepositoryOpen,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            AppLocalizations.of(context)!.openRepositoryToManageTags,
          ),
        ],
      ),
    );
  }
}
