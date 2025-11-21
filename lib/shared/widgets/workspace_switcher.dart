import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_menu_item.dart';
import '../components/base_switcher.dart';
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/models/workspace.dart';

/// Button widget for quickly switching between workspaces
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = ref.watch(selectedProjectProvider);
    final allProjects = ref.watch(projectProvider);
    final l10n = AppLocalizations.of(context)!;

    // Hide if no workspaces exist
    if (allProjects.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get display name
    final displayName = selectedProject?.name ?? l10n.allWorkspaces;

    return BaseSwitcher(
      icon: selectedProject?.id == 'default'
          ? PhosphorIconsBold.house
          : PhosphorIconsBold.folder,
      label: displayName,
      tooltip: allProjects.length > 1
          ? AppLocalizations.of(context)!.tooltipSwitchWorkspace
          : displayName,
      showDropdown: allProjects.length > 1,
      onTap: allProjects.length > 1
          ? () => _showWorkspaceMenu(context, ref, allProjects)
          : null,
    );
  }

  void _showWorkspaceMenu(BuildContext context, WidgetRef ref, List<Workspace> projects) {
    final selectedProject = ref.read(selectedProjectProvider);
    final l10n = AppLocalizations.of(context)!;

    showMenu<Workspace>(
      context: context,
      position: _getMenuPosition(context),
      items: projects.map((project) {
        final isSelected = selectedProject?.id == project.id;
        return PopupMenuItem<Workspace>(
          value: project,
          child: MenuItemContentTwoLine(
            icon: project.id == 'default'
                ? PhosphorIconsBold.house
                : PhosphorIconsBold.folder,
            primaryLabel: project.name,
            secondaryLabel: l10n.repositoryCount(project.repositoryPaths.length),
            iconColor: project.color,
            isSelected: isSelected,
            showCheck: true,
            iconSize: AppTheme.iconS,
            spacing: AppTheme.paddingM,
          ),
        );
      }).toList(),
    ).then((selectedProjectFromMenu) {
      if (selectedProjectFromMenu != null) {
        ref.read(selectedProjectProvider.notifier).selectProject(selectedProjectFromMenu);
      }
    });
  }

  RelativeRect _getMenuPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay);

    // Position menu below the button by using bottomLeft instead of topLeft
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        Offset(topLeft.dx, bottomRight.dy), // Start from bottom-left of button
        bottomRight,
      ),
      Offset.zero & overlay.size,
    );
    return position;
  }
}
