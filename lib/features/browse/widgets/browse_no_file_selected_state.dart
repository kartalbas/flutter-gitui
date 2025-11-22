import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// No file selected state for browse screen
class BrowseNoFileSelectedState extends StatelessWidget {
  const BrowseNoFileSelectedState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.file,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(
            AppLocalizations.of(context)!.noFileSelected,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            AppLocalizations.of(context)!.selectFileToViewHistoryOrPreview,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
