import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/stash.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/utils/result_extensions.dart';
import 'dialogs/create_stash_dialog.dart';
import 'dialogs/clear_all_stashes_dialog.dart';
import 'widgets/stash_list_tile.dart';
import 'widgets/stashes_no_repository_state.dart';
import 'widgets/stashes_error_state.dart';
import 'widgets/stashes_empty_state.dart';
import 'services/stashes_service.dart';

/// Stashes screen - Stash management
class StashesScreen extends ConsumerStatefulWidget {
  const StashesScreen({super.key});

  @override
  ConsumerState<StashesScreen> createState() => _StashesScreenState();
}

class _StashesScreenState extends ConsumerState<StashesScreen> {
  final _stashesService = const StashesService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final stashesAsync = ref.watch(stashesProvider);

    if (repositoryPath == null) {
      return const StashesNoRepositoryState();
    }

    return Scaffold(
      appBar: StandardAppBar(
        title: AppDestination.stashes.label(context),
        onRefresh: () => ref.read(gitActionsProvider).refreshStashes(),
        moreMenuItems: [
          // Create action always first
          PopupMenuItem(
            child: MenuItemContent(
              icon: PhosphorIconsRegular.plus,
              label: AppLocalizations.of(context)!.createStash,
            ),
            onTap: () => _showCreateStashDialog(context),
          ),
          const PopupMenuDivider(),
          // Clear All action
          PopupMenuItem(
            child: MenuItemContent(
              icon: PhosphorIconsRegular.trash,
              label: AppLocalizations.of(context)!.clearAll,
              iconColor: Theme.of(context).colorScheme.error,
              labelColor: Theme.of(context).colorScheme.error,
            ),
            onTap: () => _confirmClearAllStashes(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: stashesAsync.when(
                data: (stashes) => _buildStashList(context, stashes),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => StashesErrorState(error: error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStashList(BuildContext context, List<GitStash> stashes) {
    if (stashes.isEmpty) {
      return StashesEmptyState(
        onCreateStash: () => _showCreateStashDialog(context),
      );
    }

    // Filter stashes based on search query
    final filteredStashes = _stashesService.filterStashes(
      stashes: stashes,
      searchQuery: _searchQuery,
    );

    return Column(
      children: [
        // Search bar - always show to match branches/tags screens
        InlineSearchField(
          controller: _searchController,
          hintText: AppLocalizations.of(context)!.hintTextSearchStashes,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onClear: () {
            setState(() {
              _searchQuery = '';
            });
          },
        ),

        // Stash list
        Expanded(
          child: filteredStashes.isEmpty
              ? Center(
                  child: BodyLargeLabel(
                    'No stashes match "$_searchQuery"',
                  ),
                )
              : ListView.builder(
                  itemCount: filteredStashes.length,
                  itemBuilder: (context, index) {
                    return StashListTile(stash: filteredStashes[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateStashDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateStashDialog(),
    );

    if (result != null && context.mounted) {
      final message = result['message'] as String;
      final includeUntracked = result['includeUntracked'] as bool;
      final keepIndex = result['keepIndex'] as bool;
      final stashAllFiles = result['stashAllFiles'] as bool;
      final selectedFiles = result['selectedFiles'] as List<String>;

      await ref.read(gitActionsProvider).createStash(
        message: message.isEmpty ? null : message,
        includeUntracked: includeUntracked,
        keepIndex: keepIndex,
        files: stashAllFiles ? null : selectedFiles,
      );

      if (mounted) {
        context.showSuccessIfMounted(
          AppLocalizations.of(context)!.stashCreatedSuccess,
        );
      }
    }
  }

  Future<void> _confirmClearAllStashes(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ClearAllStashesDialog(),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(gitActionsProvider).clearStashes();
      if (mounted) {
        context.showSuccessIfMounted(
          AppLocalizations.of(context)!.allStashesClearedSuccess,
        );
      }
    }
  }
}
