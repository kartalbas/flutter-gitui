import 'package:flutter/material.dart';
import '../../../shared/components/base_animated_widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../core/workspace/models/workspace.dart';

/// Workspace card widget for grid view
class WorkspaceCard extends StatelessWidget {
  final Workspace project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const WorkspaceCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      isSelected: isSelected,
      onTap: onTap,
      customBorderColor: project.color,
      customBackgroundColor: isSelected
          ? project.color.withValues(alpha: 0.1)
          : null,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: project.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  project.id == 'default'
                      ? PhosphorIconsBold.house
                      : PhosphorIconsBold.folder,
                  color: project.color,
                  size: AppTheme.iconL,
                ),
              ),
              const Spacer(),
              BasePopupMenuButton<String>(
                icon: Icon(
                  PhosphorIconsRegular.dotsThreeVertical,
                  color: project.color,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: MenuItemContent(
                      icon: PhosphorIconsRegular.pencil,
                      label: AppLocalizations.of(context)!.edit,
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: MenuItemContent(
                        icon: PhosphorIconsRegular.trash,
                        label: AppLocalizations.of(context)!.delete,
                        iconColor: Theme.of(context).colorScheme.error,
                        labelColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingM),

          // Project name
          TitleLargeLabel(
            project.name,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurface,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (project.description != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              project.description!,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppTheme.paddingM),

          // Repository count
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.gitCommit,
                size: AppTheme.iconS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingS),
              BodySmallLabel(
                AppLocalizations.of(context)!.repositoriesCount(project.repositoryPaths.length),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
