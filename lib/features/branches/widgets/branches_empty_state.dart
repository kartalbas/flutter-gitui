import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';

/// Empty state for branches when no branches exist
class BranchesEmptyState extends StatelessWidget {
  final bool isLocal;

  const BranchesEmptyState({
    super.key,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLocal ? PhosphorIconsRegular.folder : PhosphorIconsRegular.cloud,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingM),
          TitleMediumLabel(
            isLocal
                ? AppLocalizations.of(context)!.noLocalBranches
                : AppLocalizations.of(context)!.noRemoteBranches,
          ),
        ],
      ),
    );
  }
}
