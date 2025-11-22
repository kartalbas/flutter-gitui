import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/branch.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/services/services.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../repositories/dialogs/create_branch_dialog.dart';
import 'widgets/branch_list_tile.dart';
import 'widgets/branches_empty_state.dart';
import 'widgets/branches_error_state.dart';
import 'services/branches_service.dart';
import '../../shared/components/base_menu_item.dart';

/// Branches screen - Local, remote, and tags
class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> with TickerProviderStateMixin {
  final _branchesService = const BranchesService();
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: Duration.zero, // Will be updated in didChangeDependencies
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update tab animation duration based on theme settings
    final animDuration = context.standardAnimation;
    if (_tabController.animationDuration != animDuration) {
      final oldController = _tabController;
      _tabController = TabController(
        length: 2,
        vsync: this,
        animationDuration: animDuration,
        initialIndex: oldController.index,
      );
      oldController.dispose();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final localBranchesAsync = ref.watch(localBranchesProvider);
    final remoteBranchesAsync = ref.watch(remoteBranchesProvider);

    // No repository open
    if (repositoryPath == null) {
      return const NoRepositoryEmptyState();
    }

    return Scaffold(
      appBar: StandardAppBar(
        title: AppDestination.branches.label(context),
        onRefresh: () => ref.read(gitActionsProvider).refreshBranches(),
        moreMenuItems: [
          // Create action always first
          PopupMenuItem(
            child: MenuItemContent(
              icon: PhosphorIconsRegular.plus,
              label: l10n.createBranch,
            ),
            onTap: () => _showCreateBranchDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Inline search field
            InlineSearchField(
              controller: _searchController,
              hintText: 'Search branches...',
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
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.localTab, icon: const Icon(PhosphorIconsRegular.folder, size: 16)),
                Tab(text: l10n.remoteTab, icon: const Icon(PhosphorIconsRegular.cloud, size: 16)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Local Branches
                  _buildBranchList(
                    context,
                    localBranchesAsync,
                    isLocal: true,
                  ),
                  // Remote Branches
                  _buildBranchList(
                    context,
                    remoteBranchesAsync,
                    isLocal: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchList(
    BuildContext context,
    AsyncValue<List<GitBranch>> branchesAsync, {
    required bool isLocal,
  }) {
    return branchesAsync.when(
      data: (branches) {
        if (branches.isEmpty) {
          return BranchesEmptyState(isLocal: isLocal);
        }

        // Filter by search query
        final filteredBranches = _branchesService.filterBranches(
          branches: branches,
          searchQuery: _searchQuery,
        );

        if (filteredBranches.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.noMatchesFound('branches', _searchQuery)),
          );
        }

        return ListView.builder(
          itemCount: filteredBranches.length,
          itemBuilder: (context, index) {
            final branch = filteredBranches[index];
            return BranchListTile(
              branch: branch,
              isLocal: isLocal,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => BranchesErrorState(error: error),
    );
  }

  Future<void> _showCreateBranchDialog(BuildContext context) async{
    final repositoryPath = ref.read(currentRepositoryPathProvider);
    if (repositoryPath == null) return;

    // Create a WorkspaceRepository from the current repository
    final repository = WorkspaceRepository.fromPath(repositoryPath);

    final result = await showCreateBranchDialog(
      context,
      repositories: [repository],
    );

    if (result != null && context.mounted) {
      try {
        // Create the branch using the full branch name (includes prefix)
        await ref.read(gitActionsProvider).createBranch(
              result.fullBranchName,
              checkout: result.checkout,
            );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to create branch: $e',
          );
        }
      }
    }
  }
}
