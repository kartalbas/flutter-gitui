import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../components/base_switcher.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, MenuChoice, MenuEntry;
import '../../core/workspace/workspace_list_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/workspace/default_workspace_text.dart';
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
    final displayName =
        selectedProject?.displayName(l10n) ?? l10n.allWorkspaces;

    return BaseSwitcher(
      icon: selectedProject?.isDefaultWorkspace ?? false
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

  void _showWorkspaceMenu(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> projects,
  ) {
    final selectedProject = ref.read(selectedProjectProvider);
    final l10n = AppLocalizations.of(context)!;

    // The repository count is a second FACT about each workspace, so it goes
    // in the slot for one. It used to be a second line drawn by hand here,
    // which is the application deciding an arrangement; `MenuChoice.detail`
    // states it and lets each language place it.
    openSwitcherMenu(context, <MenuEntry>[
      for (final Workspace project in projects)
        MenuChoice(
          // The mark is stated as a ROLE and drawn by the skin. It was a
          // Phosphor Bold glyph placed here by hand; a role carries no weight
          // (#249 conflict C3), so the row now renders at whatever stroke the
          // language uses for a menu's leading mark. Recorded in the weight
          // ledger rather than fought.
          icon: project.isDefaultWorkspace ? IconRole.house : IconRole.folder,
          label: project.displayName(l10n),
          detail: l10n.repositoryCount(project.repositoryPaths.length),
          selected: selectedProject?.id == project.id,
          onSelect: () =>
              ref.read(selectedProjectProvider.notifier).selectProject(project),
        ),
    ]);
  }
}
