import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../../core/workspace/selected_workspace_provider.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../components/base_list_item.dart';
import '../controllers/item_navigation_controller.dart';
import '../widgets/keyboard_navigable_view.dart';
import '../widgets/search_field_handoff.dart';
import '../components/base_layout.dart';
import '../../core/services/notification_service.dart';

/// Dialog for switching between workspace repositories (Ctrl+R).
///
/// Fully keyboard operable, the same way the hosted-repository picker is: the
/// search field takes focus on open, the arrow keys move the highlight through
/// the results without leaving the field, and Enter opens the highlighted
/// repository. It used to offer no keyboard path at all past the filter - the
/// rows were tappable and nothing else - so filtering with the keyboard ended
/// in a reach for the mouse.
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

  /// The result list on the shared navigation semantics: arrows rove its
  /// highlight (from the field via the handoff, or from the list as its own
  /// Tab stop) and activation opens the highlighted repository.
  late final ItemNavigationController _listController;

  /// The repositories currently on screen, refreshed every build, so
  /// activation resolves an index against exactly what the user sees.
  List<WorkspaceRepository> _matches = const [];

  /// Height of one result row, for keeping the highlight scrolled into view.
  /// A fixed extent is what lets the list scroll the highlight into view at
  /// all, so it is sized for the tallest row: name, path and the "invalid
  /// repository" warning, plus the list item's own padding.
  static const double _rowExtent = 104;

  @override
  void initState() {
    super.initState();
    _listController = ItemNavigationController(onActivate: _activateIndex);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _activateIndex(int index) {
    if (index < 0 || index >= _matches.length) return;
    final repository = _matches[index];
    // An invalid repository cannot be opened; activating it would close the
    // dialog on a snackbar the user never asked for.
    if (!repository.isValidGitRepo) return;
    _switchRepository(repository);
  }

  /// Enter from anywhere in the dialog opens the highlighted repository,
  /// falling back to the first one while nothing is highlighted yet.
  void _confirm() {
    if (_matches.isEmpty) return;
    final index = _listController.selectedIndex;
    _activateIndex(index < 0 ? 0 : index.clamp(0, _matches.length - 1));
  }

  /// Restarts the highlight at the first row of a fresh result set, where the
  /// old position would point at an unrelated repository.
  void _resetHighlight() {
    _listController.select(-1);
    _listController.scheduleInitialHighlight();
  }

  @override
  Widget build(BuildContext context) {
    final currentRepo = ref.watch(currentWorkspaceRepositoryProvider);
    final allRepositories = ref.watch(workspaceProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    // Filter repositories by selected project
    final repositories = selectedProject != null
        ? allRepositories
              .where((repo) => selectedProject.containsRepository(repo.path))
              .toList()
        : allRepositories;

    // Filter repositories by search query
    final filteredRepos = repositories.where((repo) {
      if (_searchQuery.isEmpty) return true;
      return repo.displayName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          repo.path.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort: favorites first, then by last accessed
    filteredRepos.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.lastAccessed.compareTo(a.lastAccessed);
    });
    _matches = filteredRepos;
    if (_matches.isNotEmpty) {
      // The first match is highlighted from the start, so Enter without any
      // arrow key takes it.
      _listController.scheduleInitialHighlight();
    }

    return BaseDialog(
      // Drawn at Phosphor BOLD before the conversion: same mark, heavier
      // stroke. A role carries no weight (#249 conflict C3) and nothing here
      // is a state, so the header mark now takes the ordinary stroke — the
      // one this mark takes at 21 other sites. Recorded and pinned by
      // `test/shared/icons/icon_weight_census_test.dart`.
      icon: IconRole.gitCommit,
      title: AppLocalizations.of(context)!.switchRepository,
      // Enter opens the highlighted repository from anywhere in the dialog.
      onSubmit: _matches.isEmpty ? null : _confirm,
      content: Column(
        children: [
          // Arrows typed in the field move the list's highlight and Enter
          // takes the highlighted repository while the caret stays in the
          // field.
          SearchFieldHandoff(
            controller: _listController,
            child: BaseTextField(
              controller: _searchController,
              autofocus: true,
              hintText: AppLocalizations.of(context)!.searchRepositories,
              prefixIcon: IconRole.magnifyingGlass,
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _resetHighlight();
              },
            ),
          ),
          const BaseGap(Proximity.grouped),

          // Repository list needs a bounded height: BaseDialog wraps the
          // content in a SingleChildScrollView, so a flex child would sit in
          // an unbounded Column and throw. The cap lets the dialog grow with
          // its content up to 400 and scroll beyond that.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: filteredRepos.isEmpty
                ? Center(
                    heightFactor: 2,
                    child: BaseLabel(
                      AppLocalizations.of(context)!.noRepositoriesFound,
                      role: TextRole.body,
                      tone: Tone.muted,
                    ),
                  )
                // A navigable collection: one Tab stop with the roving
                // highlight the field's handoff drives, kept scrolled into
                // view by the fixed row extent.
                : KeyboardNavigableListView(
                    controller: _listController,
                    itemCount: _matches.length,
                    itemExtent: _rowExtent,
                    itemBuilder: (context, index, isSelected, containerHasFocus) {
                      final repo = _matches[index];
                      final isActive = currentRepo?.path == repo.path;

                      return BaseListItem(
                        // The row the keyboard is on carries the selection
                        // styling; the repository that happens to be open is
                        // marked by its check icon instead, so the two never
                        // compete for the same visual.
                        isSelected: isSelected,
                        // The highlight follows the caret in the search
                        // field, so it keeps its full strength while the
                        // field drives it.
                        containerHasFocus: true,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Active indicator
                            SizedBox(
                              width: AppTheme.paddingL,
                              // Both marks below are drawn at Phosphor BOLD and
                              // stay raw for that reason: a role carries no
                              // weight (#249 conflict C3), the star's solid
                              // variant is one the census pins deliberately,
                              // and giving a weight up is a P3a decision rather
                              // than a side effect of converting a SIZE. Their
                              // `AppTheme.icon*` reads survive this phase.
                              child: isActive
                                  ? Icon(
                                      PhosphorIconsBold.check,
                                      size: AppTheme.iconM,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                            ),
                            const BaseGap(Proximity.related),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BaseLabel(
                              repo.displayName,
                              role: TextRole.body,
                              maxLines: 1,
                            ),
                            BaseLabel(
                              repo.path,
                              role: TextRole.detail,
                              maxLines: 1,
                            ),
                            if (!repo.isValidGitRepo)
                              Row(
                                children: [
                                  // 12 px before the conversion. The XS rung of
                                  // the old icon scale is not a meaning
                                  // ControlScale keeps: a mark beside a line of
                                  // detail is a dense mark, which is what the
                                  // 16 px inline marks elsewhere already say.
                                  const BaseIcon(
                                    IconRole.warningCircle,
                                    scale: ControlScale.compact,
                                    tone: Tone.danger,
                                  ),
                                  const BaseGap(Proximity.hairline),
                                  BaseLabel(
                                    AppLocalizations.of(
                                      context,
                                    )!.invalidRepository,
                                    role: TextRole.detail,
                                    tone: Tone.danger,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        // Survives the tone conversion whole, like the two
                        // marks in the leading slot above: the glyph is a
                        // Phosphor BOLD constant, a weight `IconRole` cannot
                        // carry (conflict C3), so converting the colour alone
                        // would drop the stroke silently. The accent/muted
                        // conditional is the row's validity restated on its
                        // mark and converts with the weight when the row is a
                        // member that draws its own trailing mark.
                        trailing: Icon(
                          PhosphorIconsBold.gitCommit,
                          color: repo.isValidGitRepo
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        isSelectable: repo.isValidGitRepo,
                        onTap: repo.isValidGitRepo
                            ? () => _switchRepository(repo)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        // Closing the *repository* is an action on the workspace that only
        // exists while one is open, not a way out of this dialog - hence a
        // peer, and hence still conditional now that the element is data.
        if (currentRepo != null)
          DialogAction(
            label: AppLocalizations.of(context)!.closeRepository,
            role: DialogActionRole.neutral,
            onPressed: _closeRepository,
          ),
        // Picking a repository from the list is the affirmative action (Enter
        // on the highlighted row, see onSubmit above); this leaves without it.
        DialogAction(
          label: AppLocalizations.of(context)!.close,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _switchRepository(WorkspaceRepository repo) async {
    if (!repo.isValidGitRepo) {
      if (mounted) {
        NotificationService.showError(
          context,
          AppLocalizations.of(context)!.repositoryInvalidOrMissing,
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
    final success = await ref
        .read(gitActionsProvider)
        .openRepository(repo.path);

    if (success && mounted) {
      // The switch went through, which is `success` - not the git-added
      // green the fill borrowed. The one second it asked for is the skin's
      // answer to "brief" now.
      NotificationService.showSuccess(
        context,
        AppLocalizations.of(
          context,
        )!.switchedToRepository(repo.displayName, repo.path, repo.displayName),
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
      NotificationService.showInfo(
        context,
        AppLocalizations.of(context)!.repositoryClosed,
      );
    }
  }
}
