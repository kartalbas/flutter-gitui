import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// Error state for stashes screen when loading fails
class StashesErrorState extends StatelessWidget {
  final Object error;

  const StashesErrorState({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(
            AppLocalizations.of(context)!.errorLoadingStashes,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            error.toString(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
