import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_dialog.dart';
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/default_workspace_text.dart';
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
class WorkspacesScreen extends ConsumerStatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  ConsumerState<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<WorkspacesScreen> {
  /// Width one grid card may take, matching the grid delegate below.
  static const double _cardMaxCrossAxisExtent = 350;

  late final ItemNavigationController _navigationController;

  /// The workspaces currently shown, in collection order, so the keyboard
  /// activation resolves an index against exactly what the user sees. Grid
  /// and list render the same order, so one controller serves both modes.
  List<Workspace> _visibleProjects = const [];

  @override
  void initState() {
    super.initState();
    _navigationController = ItemNavigationController(
      onActivate: _activateProjectAt,
    );
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  /// The keyboard activation of a workspace: select it, exactly what a
  /// click does.
  void _activateProjectAt(int index) {
    if (index < 0 || index >= _visibleProjects.length) return;
    ref
        .read(selectedProjectProvider.notifier)
        .selectProject(_visibleProjects[index]);
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final hasProjects = projects.isNotEmpty;

    _visibleProjects = projects;
    if (hasProjects) {
      _navigationController.scheduleInitialHighlight();
    }

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
                          icon: Icon(
                            PhosphorIconsRegular.listBullets,
                            size: 18,
                          ),
                        ),
                      ],
                      selected: {viewMode},
                      onSelectionChanged: (Set<ProjectsViewMode> newSelection) {
                        ref
                            .read(configProvider.notifier)
                            .setProjectsViewMode(newSelection.first);
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
              icon: IconRole.plus,
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
                      ? _buildProjectGrid(
                          context,
                          ref,
                          projects,
                          selectedProject,
                        )
                      : _buildProjectList(
                          context,
                          ref,
                          projects,
                          selectedProject,
                        );
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
    // The grid resolves its column count from the width, so the controller
    // must learn it here for vertical arrows to move by whole rows. Same
    // formula SliverGridDelegateWithMaxCrossAxisExtent uses.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth /
                    (_cardMaxCrossAxisExtent + AppTheme.paddingL))
                .ceil();
        _navigationController.crossAxisCount = columns < 1 ? 1 : columns;

        return KeyboardNavigableGridView(
          controller: _navigationController,
          itemCount: projects.length,
          autofocus: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _cardMaxCrossAxisExtent,
            childAspectRatio: 0.95,
            crossAxisSpacing: AppTheme.paddingL,
            mainAxisSpacing: AppTheme.paddingL,
          ),
          itemBuilder: (context, index, isHighlighted, containerHasFocus) {
            final project = projects[index];
            final isSelected = selectedProject?.id == project.id;

            return WorkspaceCard(
              project: project,
              isSelected: isSelected,
              isHighlighted: isHighlighted,
              containerHasFocus: containerHasFocus,
              onTap: () {
                // A click moves the highlight to the card it acted on, so
                // keyboard and mouse stay in one story.
                _navigationController.select(index);
                _activateProjectAt(index);
              },
              onEdit: () => _editProject(context, ref, project),
              onDelete: !project.isDefaultWorkspace
                  ? () => _deleteProject(context, ref, project)
                  : null,
            );
          },
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
    _navigationController.crossAxisCount = 1;

    return KeyboardNavigableListView(
      controller: _navigationController,
      itemCount: projects.length,
      autofocus: true,
      itemBuilder: (context, index, isHighlighted, containerHasFocus) {
        final project = projects[index];
        final isSelected = selectedProject?.id == project.id;

        return WorkspaceListItem(
          project: project,
          isSelected: isSelected,
          isHighlighted: isHighlighted,
          containerHasFocus: containerHasFocus,
          onTap: () {
            // A click moves the highlight to the row it acted on, so
            // keyboard and mouse stay in one story.
            _navigationController.select(index);
            _activateProjectAt(index);
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
        await ref
            .read(projectProvider.notifier)
            .createWorkspace(
              name: result.name,
              description: result.description,
              color: result.color,
            );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to create workspace: $e',
          );
        }
      }
    }
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    Workspace project,
  ) async {
    final result = await showProjectDialog(context, project: project);

    if (result != null && context.mounted) {
      try {
        await ref
            .read(projectProvider.notifier)
            .updateWorkspace(
              project.id,
              name: result.name,
              description: result.description,
              color: result.color,
            );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to update workspace: $e',
          );
        }
      }
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Workspace project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return BaseDialog(
          title: l10n.deleteWorkspace,
          content: Text(
            l10n.dialogContentDeleteWorkspace(project.displayName(l10n)),
          ),
          variant: DialogVariant.destructive,
          actions: [
            DialogAction(
              label: l10n.cancel,
              role: DialogActionRole.dismissive,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            DialogAction(
              label: l10n.delete,
              role: DialogActionRole.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(projectProvider.notifier).deleteWorkspace(project.id);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to delete workspace: $e',
          );
        }
      }
    }
  }
}
