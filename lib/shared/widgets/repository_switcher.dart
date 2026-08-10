import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, MenuChoice, MenuEntry;

import '../../generated/app_localizations.dart';
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
        ? allRepositories
              .where((repo) => selectedProject.containsRepository(repo.path))
              .toList()
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

  void _showRepositoryMenu(
    BuildContext context,
    WidgetRef ref,
    List<WorkspaceRepository> repositories,
  ) {
    final currentPath = ref.read(currentRepositoryPathProvider);

    // The path is a second FACT about each repository, stated rather than
    // arranged: it used to be a second line drawn by hand here.
    openSwitcherMenu(context, <MenuEntry>[
      for (final WorkspaceRepository repo in repositories)
        MenuChoice(
          // A role, not the Bold glyph this row used to place by hand: the
          // weight is the skin's once the mark is a meaning. See the ledger.
          icon: IconRole.gitCommit,
          label: repo.displayName,
          detail: repo.path,
          selected: currentPath == repo.path,
          onSelect: () =>
              ref.read(configProvider.notifier).setCurrentRepository(repo.path),
        ),
    ]);
  }
}
