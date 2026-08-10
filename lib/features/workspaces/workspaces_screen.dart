import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ChoiceGroupSpec,
        ChoiceOption,
        ContentPort,
        GridDensity,
        IconRole,
        Inset,
        MenuAction,
        ScreenSpec,
        Skin,
        SkinScope,
        TileHeight,
        ToolbarChoiceEntry,
        ToolbarEntry,
        ToolbarGroup,
        ToolbarMenuEntry;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/screen_body_host.dart';
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
import '../../shared/components/base_layout.dart';

/// Workspaces screen - shows all workspaces and allows selection
class WorkspacesScreen extends ConsumerStatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  ConsumerState<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<WorkspacesScreen> {
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

    final l10n = AppLocalizations.of(context)!;

    // The frame is `chrome.screen`'s (#442), and with it the view switch stops
    // being a Material widget this screen names. It used to be a raw
    // `SegmentedButton` handed to `StandardAppBar.additionalActions` - the one
    // slot in that bar that took a pre-built widget, and therefore the one
    // place a design language's own control was welded into an application
    // file. It is now a `ToolbarChoiceEntry` carrying a `ChoiceGroupSpec`, and
    // each language answers "pick one of a few, in a bar" for itself.
    //
    // What changes on screen, named. The segments were icon-only with NO
    // tooltip, which this repository's rules forbid outright;
    // `ChoiceOption.label` is required and doubles as the accessible name,
    // and Material's bar renders each segment with it as the tooltip, so the
    // switch now names itself to the pointer and to a screen reader. The
    // segment's box is the skin's segmented-button arithmetic instead of the
    // 18-pixel glyph this file specified (M3's default lands on the same
    // number, stated by the skin). And the gap between the switch and the
    // overflow anchor is the bar's uniform entry spacing (8) where this file
    // used to state `BaseGap(Proximity.grouped)` = 16 - the member's rhythm
    // is one spacing for every bar entry, and the screen no longer states
    // its own.
    return SkinScope.render(
      context,
      (Skin skin, BuildContext inner) => skin.chrome.screen(
        inner,
        ScreenSpec(
          title: AppDestination.workspaces.label(context),
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              if (hasProjects)
                ToolbarChoiceEntry<ProjectsViewMode>(
                  ChoiceGroupSpec<ProjectsViewMode>(
                    label: l10n.viewOptions,
                    selected: ref.watch(projectsViewModeProvider),
                    onSelected: (ProjectsViewMode mode) => ref
                        .read(configProvider.notifier)
                        .setProjectsViewMode(mode),
                    options: <ChoiceOption<ProjectsViewMode>>[
                      ChoiceOption<ProjectsViewMode>(
                        value: ProjectsViewMode.grid,
                        label: l10n.viewModeGrid,
                        icon: IconRole.gridFour,
                      ),
                      ChoiceOption<ProjectsViewMode>(
                        value: ProjectsViewMode.list,
                        label: l10n.viewModeList,
                        icon: IconRole.listBullets,
                      ),
                    ],
                  ),
                ),
              ToolbarMenuEntry(
                icon: IconRole.dotsThreeVertical,
                tooltip: l10n.moreActions,
                entries: [
                  // New workspace action (first)
                  MenuAction(
                    icon: IconRole.plus,
                    label: l10n.tooltipNewWorkspace,
                    onPressed: () => _createProject(context, ref),
                  ),
                ],
              ),
            ]),
          ],
          body: ContentPort(
            ScreenBodyHost(
              child: BaseInset(
                all: Inset.roomy,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectGrid(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> projects,
    Workspace? selectedProject,
  ) {
    // The grid's geometry is `layout.grid`'s: the screen states how tightly
    // packed the cards should sit and that each card decides its own height —
    // a workspace card grows with its content, and no fixed tile proportion
    // holds it at every window width (#438) — and the member answers with the
    // tile extent, its gutters and, through `GridSpec.onColumnsChanged`, the
    // column count the keyboard controller needs. `normal` is the rung that
    // carries the 350 pixels these cards were laid out at.
    return KeyboardNavigableGridView(
      controller: _navigationController,
      itemCount: projects.length,
      autofocus: true,
      density: GridDensity.normal,
      tileHeight: TileHeight.content,
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BaseDialog.show<bool>(
      context: context,
      dialog: BaseDialog(
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
      ),
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
