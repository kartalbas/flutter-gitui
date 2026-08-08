import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// No repository state for browse screen
class BrowseNoRepositoryState extends StatelessWidget {
  const BrowseNoRepositoryState({super.key});

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
          BaseLabel(
            AppLocalizations.of(context)!.noRepositoryOpen,
            role: TextRole.pageTitle,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            AppLocalizations.of(context)!.openRepositoryToBrowseFiles,
            role: TextRole.body,
          ),
        ],
      ),
    );
  }
}
