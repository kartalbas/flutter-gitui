import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';

/// Error state for branches screen when loading fails
class BranchesErrorState extends StatelessWidget {
  final Object error;

  const BranchesErrorState({
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
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingM),
          TitleMediumLabel(
            AppLocalizations.of(context)!.errorLoadingBranches(error.toString()),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
