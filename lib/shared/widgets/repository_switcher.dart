import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_menu_item.dart';
import '../components/base_switcher.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/config/config_providers.dart';
import '../../core/workspace/models/workspace_repository.dart';

/// Button widget for quickly switching between workspace repositories
class RepositorySwitcher extends ConsumerWidget {
  const RepositorySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRepo = ref.watch(currentWorkspaceRepositoryProvider);
    final currentPath = ref.watch(currentRepositoryPathProvider);
    final allRepositories = ref.watch(workspaceProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    // Filter repositories by selected project
    final repositories = selectedProject != null
        ? allRepositories.where((repo) => selectedProject.containsRepository(repo.path)).toList()
        : allRepositories;

    // Get display name - either from workspace repo or from path
    String displayName;
    if (currentRepo != null) {
      displayName = currentRepo.displayName;
    } else if (currentPath != null) {
      // Extract folder name from path
      displayName = currentPath.split(Platform.pathSeparator).last;
    } else {
      final l10n = AppLocalizations.of(context)!;
      displayName = l10n.emptyStateNoRepository;
    }

    // Always show if we have repositories in workspace
    // Hide only if no repositories exist at all
    if (repositories.isEmpty && currentPath == null) {
      return const SizedBox.shrink();
    }

    return BaseSwitcher(
      icon: PhosphorIconsBold.gitCommit,
      label: displayName,
      tooltip: repositories.length > 1
          ? AppLocalizations.of(context)!.tooltipSwitchRepository
          : displayName,
      showDropdown: repositories.length > 1,
      onTap: repositories.length > 1
          ? () => _showRepositoryMenu(context, ref, repositories)
          : null,
    );
  }

  void _showRepositoryMenu(BuildContext context, WidgetRef ref, List<WorkspaceRepository> repositories) {
    final currentPath = ref.read(currentRepositoryPathProvider);

    showMenu<WorkspaceRepository>(
      context: context,
      position: _getMenuPosition(context),
      items: repositories.map((repo) {
        final isSelected = currentPath == repo.path;
        return PopupMenuItem<WorkspaceRepository>(
          value: repo,
          child: MenuItemContentTwoLine(
            icon: PhosphorIconsBold.gitCommit,
            primaryLabel: repo.displayName,
            secondaryLabel: repo.path,
            iconColor: Theme.of(context).colorScheme.primary,
            isSelected: isSelected,
            showCheck: true,
            iconSize: AppTheme.iconS,
            spacing: AppTheme.paddingM,
          ),
        );
      }).toList(),
    ).then((selectedRepo) {
      if (selectedRepo != null) {
        ref.read(configProvider.notifier).setCurrentRepository(selectedRepo.path);
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
