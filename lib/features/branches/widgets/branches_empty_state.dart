import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';

/// Empty state for branches when no branches exist
class BranchesEmptyState extends StatelessWidget {
  final bool isLocal;

  const BranchesEmptyState({super.key, required this.isLocal});

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
          // An empty state's headline, which every other empty state in the
          // application already draws one rung larger. Saying `pageTitle` here
          // is what removes that disagreement.
          BaseLabel(
            isLocal
                ? AppLocalizations.of(context)!.noLocalBranches
                : AppLocalizations.of(context)!.noRemoteBranches,
            role: TextRole.pageTitle,
          ),
        ],
      ),
    );
  }
}
