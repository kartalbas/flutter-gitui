import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// Clean working directory state for changes screen
class ChangesCleanState extends StatelessWidget {
  const ChangesCleanState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.checkCircle,
            size: 64,
            color: context.gitColors.added,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseLabel(
            AppLocalizations.of(context)!.workingDirectoryClean,
            role: TextRole.pageTitle,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            AppLocalizations.of(context)!.noChangesToCommit,
            role: TextRole.body,
          ),
        ],
      ),
    );
  }
}
