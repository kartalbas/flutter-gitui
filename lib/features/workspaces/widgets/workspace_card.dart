import 'package:flutter/material.dart';
import '../../../shared/components/base_animated_widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../core/workspace/default_workspace_text.dart';
import '../../../core/workspace/models/workspace.dart';

/// Workspace card widget for grid view
class WorkspaceCard extends StatelessWidget {
  final Workspace project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  /// Whether the grid's roving highlight rests on this card.
  final bool isHighlighted;

  /// Whether the collection holding this card owns keyboard focus. Only the
  /// highlighted card wears the focus ring, and only while the collection is
  /// focused; the selected workspace keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const WorkspaceCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.isHighlighted = false,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = project.displayDescription(l10n);

    return BaseCard(
      isSelected: isSelected || isHighlighted,
      // The focus ring belongs to the roving highlight alone; the selected
      // workspace keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
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
                  project.isDefaultWorkspace
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
            project.displayName(l10n),
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurface,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (description != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              description,
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
                AppLocalizations.of(
                  context,
                )!.repositoriesCount(project.repositoryPaths.length),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
