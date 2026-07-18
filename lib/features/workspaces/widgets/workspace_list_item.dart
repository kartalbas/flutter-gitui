import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/workspace.dart';

/// List item widget displaying a workspace in a compact row format
class WorkspaceListItem extends StatelessWidget {
  final Workspace project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const WorkspaceListItem({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return BaseListItem(
      isSelected: isSelected,
      onTap: onTap,
      leading: Container(
            padding: const EdgeInsets.all(AppTheme.paddingS),
            decoration: BoxDecoration(
              color: project.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              project.id == 'default'
                  ? PhosphorIconsBold.house
                  : PhosphorIconsBold.folder,
              color: project.color,
              size: AppTheme.iconL,
            ),
          ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workspace name
          TitleMediumLabel(
            project.name,
            color: project.color,
            overflow: TextOverflow.ellipsis,
          ),

          // Description
          if (project.description != null) ...[
            const SizedBox(height: AppTheme.paddingXS),
            BodySmallLabel(
              project.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppTheme.paddingXS),

          // Repository count
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.gitCommit,
                size: AppTheme.iconXS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              BodySmallLabel(
                AppLocalizations.of(context)!.repositoriesCount(project.repositoryPaths.length),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseIconButton(
            icon: PhosphorIconsRegular.pencil,
            onPressed: onEdit,
            tooltip: AppLocalizations.of(context)!.edit,
          ),
          if (onDelete != null)
            BaseIconButton(
              icon: PhosphorIconsRegular.trash,
              onPressed: onDelete,
              tooltip: AppLocalizations.of(context)!.delete,
            ),
        ],
      ),
    );
  }
}
