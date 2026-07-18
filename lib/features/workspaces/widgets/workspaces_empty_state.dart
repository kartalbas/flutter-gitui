import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';

/// Empty state for workspaces screen when no workspaces exist
class WorkspacesEmptyState extends StatelessWidget {
  const WorkspacesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsBold.folder,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppTheme.paddingL),
          HeadlineMediumLabel(
            AppLocalizations.of(context)!.noWorkspacesYet,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyLargeLabel(
            AppLocalizations.of(context)!.createWorkspaceToOrganize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
