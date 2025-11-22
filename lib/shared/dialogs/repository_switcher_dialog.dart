import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_list_item.dart';

/// Dialog for switching between workspace repositories
class RepositorySwitcherDialog extends ConsumerStatefulWidget {
  const RepositorySwitcherDialog({super.key});

  @override
  ConsumerState<RepositorySwitcherDialog> createState() =>
      _RepositorySwitcherDialogState();
}

class _RepositorySwitcherDialogState
    extends ConsumerState<RepositorySwitcherDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRepo = ref.watch(currentWorkspaceRepositoryProvider);
    final allRepositories = ref.watch(workspaceProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    // Filter repositories by selected project
    final repositories = selectedProject != null
        ? allRepositories.where((repo) => selectedProject.containsRepository(repo.path)).toList()
        : allRepositories;

    // Filter repositories by search query
    final filteredRepos = repositories.where((repo) {
      if (_searchQuery.isEmpty) return true;
      return repo.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          repo.path.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort: favorites first, then by last accessed
    filteredRepos.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.lastAccessed.compareTo(a.lastAccessed);
    });

    return BaseDialog(
      icon: PhosphorIconsBold.gitCommit,
      title: AppLocalizations.of(context)!.switchRepository,
      content: Column(
        children: [
          // Search field
          BaseTextField(
            controller: _searchController,
            autofocus: true,
            hintText: AppLocalizations.of(context)!.searchRepositories,
            prefixIcon: PhosphorIconsRegular.magnifyingGlass,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Repository list
          Expanded(
            child: filteredRepos.isEmpty
                ? Center(
                    child: BodyLargeLabel(AppLocalizations.of(context)!.noRepositoriesFound, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                : ListView.builder(
                    itemCount: filteredRepos.length,
                    itemBuilder: (context, index) {
                      final repo = filteredRepos[index];
                      final isActive = currentRepo?.path == repo.path;

                      return BaseListItem(
                        isSelected: isActive,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Active indicator
                            SizedBox(
                              width: AppTheme.paddingL,
                              child: isActive
                                  ? Icon(
                                      PhosphorIconsBold.check,
                                      size: AppTheme.iconM,
                                      color: Theme.of(context).colorScheme.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            // Favorite star
                            if (repo.isFavorite)
                              Icon(
                                PhosphorIconsBold.star,
                                size: AppTheme.iconS,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BodyMediumLabel(
                              repo.displayName,
                            ),
                            LabelMediumLabel(
                              repo.path,
                            ),
                            if (!repo.isValidGitRepo)
                              Row(
                                children: [
                                  Icon(
                                    PhosphorIconsRegular.warningCircle,
                                    size: AppTheme.iconXS,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: AppTheme.paddingXS),
                                  LabelMediumLabel(
                                    AppLocalizations.of(context)!.invalidRepository,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: Icon(
                          PhosphorIconsBold.gitCommit,
                          color: repo.isValidGitRepo
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        isSelectable: repo.isValidGitRepo,
                        onTap: repo.isValidGitRepo ? () => _switchRepository(repo) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        if (currentRepo != null)
          BaseButton(
            label: AppLocalizations.of(context)!.closeRepository,
            variant: ButtonVariant.tertiary,
            onPressed: _closeRepository,
          ),
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _switchRepository(WorkspaceRepository repo) async {
    if (!repo.isValidGitRepo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.repositoryInvalidOrMissing),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Update last accessed
    await ref.read(workspaceProvider.notifier).markAccessed(repo.path);

    // Open in git service (also sets as current repository)
    final success = await ref.read(gitActionsProvider).openRepository(repo.path);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.switchedToRepository(repo.displayName, repo.path, repo.displayName)),
          backgroundColor: AppTheme.gitAdded,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _closeRepository() async {
    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Close the current repository
    await ref.read(gitActionsProvider).closeRepository();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.repositoryClosed),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}
