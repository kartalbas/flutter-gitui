import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../shared/components/base_select_all_button.dart';
import '../../../core/workspace/models/workspace_repository.dart';
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
    final isAllSelected = selectedRepositories.length == filteredRepositories.length &&
        filteredRepositories.isNotEmpty;

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
        if (filteredRepositories.isNotEmpty)
          BaseSelectAllButton(
            isAllSelected: isAllSelected,
            onPressed: () {
              if (isAllSelected) {
                ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
              } else {
                ref.read(repositoryMultiSelectProvider.notifier).selectAll(filteredRepositories);
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
