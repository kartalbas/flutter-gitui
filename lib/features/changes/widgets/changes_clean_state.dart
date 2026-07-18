import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
            color: AppTheme.gitAdded,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(
            AppLocalizations.of(context)!.workingDirectoryClean,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            AppLocalizations.of(context)!.noChangesToCommit,
          ),
        ],
      ),
    );
  }
}
