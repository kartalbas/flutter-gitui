import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/branch.dart';
import '../../core/services/services.dart';
import '../../shared/widgets/widgets.dart';
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

class _BranchesScreenState extends ConsumerState<BranchesScreen>
    with TickerProviderStateMixin {
  final _branchesService = const BranchesService();
  final _searchController = TextEditingController();
  late TabController _tabController;
  late final ItemNavigationController _localListController;
  late final ItemNavigationController _remoteListController;
  String _searchQuery = '';

  /// The branches each tab currently shows, in list order, so the keyboard
  /// activation resolves an index against exactly what the user sees.
  List<GitBranch> _visibleLocalBranches = const [];
  List<GitBranch> _visibleRemoteBranches = const [];

  @override
  void initState() {
    super.initState();
    _localListController = ItemNavigationController(
      onActivate: (index) => _checkoutBranchAt(_visibleLocalBranches, index),
    );
    _remoteListController = ItemNavigationController(
      onActivate: (index) => _checkoutBranchAt(_visibleRemoteBranches, index),
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration:
          Duration.zero, // Will be updated in didChangeDependencies
    )..addListener(_onTabChanged);
  }

  /// The search field hands ArrowUp/Down to the tab in front, so a tab
  /// switch must rebuild the field with the other tab's controller.
  void _onTabChanged() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update tab animation duration based on theme settings.
    //
    // #249 P2: one of the four readers of a motion value still left in the
    // application (the others are `base_animated_widgets.dart`,
    // `base_switcher.dart` and `branch_switcher.dart`). The skin owns the
    // theme now, and a `ThemeData` carries its extensions, so the
    // `AnimationSpeedExtension` this reads survives only because `main.dart`
    // re-publishes the application's own extensions below the scope - see
    // `_ApplicationThemeExtensions` there for why that bridge exists and when
    // it goes. What closes THIS reader is the member rather than the value: a
    // `TabController`'s duration cannot come from `SkinMotion`, which returns
    // widgets, so it takes the tab set itself becoming `surfaces.tabs` with
    // the controller moving with it.
    final animDuration = context.standardAnimation;
    if (_tabController.animationDuration != animDuration) {
      final oldController = _tabController;
      _tabController = TabController(
        length: 2,
        vsync: this,
        animationDuration: animDuration,
        initialIndex: oldController.index,
      )..addListener(_onTabChanged);
      oldController.dispose();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _localListController.dispose();
    _remoteListController.dispose();
    super.dispose();
  }

  /// The keyboard activation of a branch row: check the branch out, exactly
  /// what the row's own checkout affordance does. The current branch has
  /// nothing to activate.
  Future<void> _checkoutBranchAt(List<GitBranch> branches, int index) async {
    if (index < 0 || index >= branches.length) return;
    final branch = branches[index];
    if (branch.isCurrent) return;
    try {
      // Remote branches must be checked out by their bare name; passing the
      // remote-qualified ref would detach HEAD instead of creating a local
      // tracking branch. For local branches this is identical to shortName.
      await ref
          .read(gitActionsProvider)
          .switchBranch(branch.branchNameWithoutRemote);
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to checkout: $e');
      }
    }
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
            // Inline search field; arrows hand off to the list of the tab
            // in front while typing continues in the field.
            InlineSearchField(
              controller: _searchController,
              hintText: l10n.searchBranches,
              navigationController: _tabController.index == 0
                  ? _localListController
                  : _remoteListController,
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
                Tab(
                  text: l10n.localTab,
                  icon: const Icon(PhosphorIconsRegular.folder, size: 16),
                ),
                Tab(
                  text: l10n.remoteTab,
                  icon: const Icon(PhosphorIconsRegular.cloud, size: 16),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Local Branches
                  _buildBranchList(context, localBranchesAsync, isLocal: true),
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

        if (isLocal) {
          _visibleLocalBranches = filteredBranches;
        } else {
          _visibleRemoteBranches = filteredBranches;
        }

        if (filteredBranches.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(
                context,
              )!.noMatchesFound('branches', _searchQuery),
            ),
          );
        }

        final listController = isLocal
            ? _localListController
            : _remoteListController;
        listController.scheduleInitialHighlight();

        // One Tab stop with a roving highlight; arrows, Home/End and Enter
        // are the collection's keys, scoped to the collection alone.
        return KeyboardNavigableListView(
          controller: listController,
          itemCount: filteredBranches.length,
          autofocus: isLocal,
          itemBuilder: (context, index, isSelected, containerHasFocus) {
            return BranchListTile(
              branch: filteredBranches[index],
              isLocal: isLocal,
              isHighlighted: isSelected,
              containerHasFocus: containerHasFocus,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => BranchesErrorState(error: error),
    );
  }

  Future<void> _showCreateBranchDialog(BuildContext context) async {
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
        await ref
            .read(gitActionsProvider)
            .createBranch(result.fullBranchName, checkout: result.checkout);
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.snackbarFailedToCreateBranch(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
