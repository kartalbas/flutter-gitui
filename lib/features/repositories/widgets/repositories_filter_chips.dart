import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../shared/components/base_select_all_button.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/models/repository_status.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../repository_multi_select_provider.dart';

/// Filter chips and selection controls for repositories screen
class RepositoriesFilterChips extends ConsumerWidget {
  final bool filterCleanOnly;
  final bool filterWithRemote;
  final ValueChanged<bool> onFilterCleanOnlyChanged;
  final ValueChanged<bool> onFilterWithRemoteChanged;
  final List<WorkspaceRepository> filteredRepositories;
  final List<WorkspaceRepository> selectedRepositories;

  const RepositoriesFilterChips({
    super.key,
    required this.filterCleanOnly,
    required this.filterWithRemote,
    required this.onFilterCleanOnlyChanged,
    required this.onFilterWithRemoteChanged,
    required this.filteredRepositories,
    required this.selectedRepositories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mirror the per-card selectability rule: a broken repo renders neither a
    // checkbox nor a tap target, so selecting it would strand it in the selection
    final statuses = ref.watch(workspaceRepositoryStatusProvider);
    final selectableRepositories = filteredRepositories.where((r) {
      final status = statuses[r.path] ?? RepositoryStatus.unknown;
      return r.isValidGitRepo && (status.isLoading || !status.isBroken);
    }).toList();

    // Selection is tracked over the unfiltered repo list, so only containment of
    // every visible repo may flip the button to 'Deselect all'
    final selectedPaths = selectedRepositories.map((r) => r.path).toSet();
    final isAllSelected = selectableRepositories.isNotEmpty &&
        selectableRepositories.every((r) => selectedPaths.contains(r.path));

    return Row(
      children: [
        // Filter chips
        Wrap(
          spacing: AppTheme.paddingS,
          children: [
            BaseFilterChip(
              label: AppLocalizations.of(context)!.cleanOnly,
              selected: filterCleanOnly,
              onSelected: onFilterCleanOnlyChanged,
              icon: PhosphorIconsRegular.check,
            ),
            BaseFilterChip(
              label: AppLocalizations.of(context)!.withRemote,
              selected: filterWithRemote,
              onSelected: onFilterWithRemoteChanged,
              icon: PhosphorIconsRegular.cloud,
            ),
          ],
        ),
        const SizedBox(width: AppTheme.paddingM),

        // Select All / Deselect All
        if (selectableRepositories.isNotEmpty)
          BaseSelectAllButton(
            isAllSelected: isAllSelected,
            onPressed: () {
              if (isAllSelected) {
                ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
              } else {
                ref.read(repositoryMultiSelectProvider.notifier).selectAll(selectableRepositories);
              }
            },
          ),

        const Spacer(),
        // Selection count
        if (selectedRepositories.isNotEmpty)
          BaseSelectionCountBadge(count: selectedRepositories.length),
      ],
    );
  }
}
