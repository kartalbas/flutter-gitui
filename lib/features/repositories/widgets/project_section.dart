import 'package:flutter/material.dart';
import '../../../shared/components/base_animated_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../core/workspace/models/workspace.dart';

/// Provider for tracking expanded state of projects
final projectExpandedProvider = StateProvider.family<bool, String>((ref, projectId) => true);

/// Section header for a project group
class ProjectSection extends ConsumerWidget {
  final Workspace? project; // null for "Unassigned"
  final int repositoryCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget child;

  const ProjectSection({
    super.key,
    this.project,
    required this.repositoryCount,
    this.onEdit,
    this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnassigned = project == null;
    final projectId = project?.id ?? 'unassigned';
    final isExpanded = ref.watch(projectExpandedProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project header
        InkWell(
          onTap: () {
            ref.read(projectExpandedProvider(projectId).notifier).state = !isExpanded;
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingL,
              vertical: AppTheme.paddingM,
            ),
            decoration: BoxDecoration(
              color: isUnassigned
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : project!.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: isUnassigned
                    ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                    : project!.color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isUnassigned
                        ? Theme.of(context).colorScheme.outline
                        : project!.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),

                // Expand/Collapse icon
                Icon(
                  isExpanded
                      ? PhosphorIconsRegular.caretDown
                      : PhosphorIconsRegular.caretRight,
                  size: AppTheme.iconM,
                  color: isUnassigned
                      ? Theme.of(context).colorScheme.onSurface
                      : project!.color,
                ),
                const SizedBox(width: AppTheme.paddingS),

                // Project icon
                Icon(
                  isUnassigned ? PhosphorIconsBold.package : PhosphorIconsBold.folder,
                  size: AppTheme.iconM,
                  color: isUnassigned
                      ? Theme.of(context).colorScheme.onSurface
                      : project!.color,
                ),
                const SizedBox(width: AppTheme.paddingM),

                // Project name and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleMediumLabel(
                        isUnassigned ? AppLocalizations.of(context)!.unassignedRepositories : project!.name,
                        color: isUnassigned
                            ? Theme.of(context).colorScheme.onSurface
                            : project!.color,
                      ),
                      if (!isUnassigned && project!.description != null) ...{
                        const SizedBox(height: 2),
                        BodySmallLabel(
                          project!.description!,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      },
                    ],
                  ),
                ),

                // Repository count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: isUnassigned
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : project!.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: LabelLargeLabel(
                    '$repositoryCount',
                    color: isUnassigned
                        ? Theme.of(context).colorScheme.onSurface
                        : project!.color,
                  ),
                ),

                // Actions (only for projects, not unassigned)
                if (!isUnassigned) ...[
                  const SizedBox(width: AppTheme.paddingS),
                  BasePopupMenuButton<String>(
                    icon: Icon(
                      PhosphorIconsRegular.dotsThreeVertical,
                      size: AppTheme.iconM,
                      color: project!.color,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.pencil,
                          label: AppLocalizations.of(context)!.editProject,
                          iconSize: AppTheme.iconS,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.trash,
                          label: AppLocalizations.of(context)!.deleteProject,
                          iconSize: AppTheme.iconS,
                          iconColor: Theme.of(context).colorScheme.error,
                          labelColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // Repositories (shown when expanded)
        if (isExpanded) ...[
          const SizedBox(height: AppTheme.paddingS),
          child,
        ],
        const SizedBox(height: AppTheme.paddingM),
      ],
    );
  }
}
