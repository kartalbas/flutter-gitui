import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_dialog.dart';
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/models/workspace.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../repositories/dialogs/project_dialog.dart';
import '../../core/services/notification_service.dart';
import 'widgets/workspace_list_item.dart';
import 'widgets/workspaces_empty_state.dart';
import 'widgets/workspace_card.dart';

/// Workspaces screen - shows all workspaces and allows selection
class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final hasProjects = projects.isNotEmpty;

    return Scaffold(
      appBar: StandardAppBar(
        title: AppDestination.workspaces.label(context),
        additionalActions: hasProjects
            ? [
                // View mode toggle
                Consumer(
                  builder: (context, ref, child) {
                    final viewMode = ref.watch(projectsViewModeProvider);
                    return SegmentedButton<ProjectsViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: ProjectsViewMode.grid,
                          icon: Icon(PhosphorIconsRegular.gridFour, size: 18),
                        ),
                        ButtonSegment(
                          value: ProjectsViewMode.list,
                          icon: Icon(PhosphorIconsRegular.listBullets, size: 18),
                        ),
                      ],
                      selected: {viewMode},
                      onSelectionChanged: (Set<ProjectsViewMode> newSelection) {
                        ref.read(configProvider.notifier).setProjectsViewMode(newSelection.first);
                      },
                    );
                  },
                ),
                const SizedBox(width: AppTheme.paddingM),
              ]
            : null,
        moreMenuItems: [
          // New workspace action (first)
          PopupMenuItem(
            child: MenuItemContent(
              icon: PhosphorIconsRegular.plus,
              label: AppLocalizations.of(context)!.tooltipNewWorkspace,
            ),
            onTap: () => _createProject(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: hasProjects
                ? Consumer(
                    builder: (context, ref, child) {
                      final viewMode = ref.watch(projectsViewModeProvider);
                      return viewMode == ProjectsViewMode.grid
                          ? _buildProjectGrid(context, ref, projects, selectedProject)
                          : _buildProjectList(context, ref, projects, selectedProject);
                    },
                  )
                : const WorkspacesEmptyState(),
      ),
    );
  }

  Widget _buildProjectGrid(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> projects,
    Workspace? selectedProject,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 0.95,
        crossAxisSpacing: AppTheme.paddingL,
        mainAxisSpacing: AppTheme.paddingL,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final isSelected = selectedProject?.id == project.id;

        return WorkspaceCard(
          project: project,
          isSelected: isSelected,
          onTap: () {
            ref.read(selectedProjectProvider.notifier).selectProject(project);
          },
          onEdit: () => _editProject(context, ref, project),
          onDelete: project.id != 'default'
              ? () => _deleteProject(context, ref, project)
              : null,
        );
      },
    );
  }

  Widget _buildProjectList(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> projects,
    Workspace? selectedProject,
  ) {
    return ListView.builder(
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final isSelected = selectedProject?.id == project.id;

        return WorkspaceListItem(
          project: project,
          isSelected: isSelected,
          onTap: () {
            ref.read(selectedProjectProvider.notifier).selectProject(project);
          },
          onEdit: () => _editProject(context, ref, project),
          onDelete: project.id != 'default'
              ? () => _deleteProject(context, ref, project)
              : null,
        );
      },
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final result = await showProjectDialog(context);

    if (result != null && context.mounted) {
      try {
        await ref.read(projectProvider.notifier).createWorkspace(
              name: result.name,
              description: result.description,
              color: result.color,
            );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to create workspace: $e');
        }
      }
    }
  }

  Future<void> _editProject(BuildContext context, WidgetRef ref, Workspace project) async {
    final result = await showProjectDialog(context, project: project);

    if (result != null && context.mounted) {
      try {
        await ref.read(projectProvider.notifier).updateWorkspace(
              project.id,
              name: result.name,
              description: result.description,
              color: result.color,
            );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to update workspace: $e');
        }
      }
    }
  }

  Future<void> _deleteProject(BuildContext context, WidgetRef ref, Workspace project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        title: AppLocalizations.of(context)!.deleteWorkspace,
        content: Text(AppLocalizations.of(context)!.dialogContentDeleteWorkspace(project.name)),
        variant: DialogVariant.destructive,
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.delete,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(projectProvider.notifier).deleteWorkspace(project.id);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to delete workspace: $e');
        }
      }
    }
  }
}
