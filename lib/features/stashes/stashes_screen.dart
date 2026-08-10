import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        DialogRouteSpec,
        IconRole,
        Inset,
        MenuAction,
        MenuActionRole,
        MenuSeparator,
        Overlays,
        ScreenSpec,
        Skin,
        SkinScope,
        TextRole,
        ToolbarActionEntry,
        ToolbarEntry,
        ToolbarGroup,
        ToolbarMenuEntry;

import '../../generated/app_localizations.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_progress.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';
import '../../shared/widgets/inline_search_field.dart';
import '../../shared/widgets/screen_body_host.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/destructive_action.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/models/stash.dart';
import '../../core/navigation/navigation_item.dart';
import '../../core/utils/result_extensions.dart';
import '../../shared/dialogs/confirm_destructive.dart';
import 'dialogs/create_stash_dialog.dart';
import 'widgets/stash_list_tile.dart';
import 'widgets/stashes_no_repository_state.dart';
import 'widgets/stashes_error_state.dart';
import 'widgets/stashes_empty_state.dart';
import 'services/stashes_service.dart';
import '../../shared/components/base_layout.dart';

/// Stashes screen - Stash management
class StashesScreen extends ConsumerStatefulWidget {
  const StashesScreen({super.key});

  @override
  ConsumerState<StashesScreen> createState() => _StashesScreenState();
}

class _StashesScreenState extends ConsumerState<StashesScreen> {
  final _stashesService = const StashesService();
  final _searchController = TextEditingController();
  late final ItemNavigationController _listController;
  String _searchQuery = '';

  /// The stashes the list currently shows, in list order, so the keyboard
  /// activation resolves an index against exactly what the user sees.
  List<GitStash> _visibleStashes = const [];

  /// One expansion state per stash, owned here so Enter on the highlighted
  /// row can open and close its details. Keyed by the stash ref; the
  /// controller holds the expanded flag itself, so it also survives the row
  /// scrolling out of the list's build window.
  final Map<String, ExpansibleController> _expansionControllers = {};

  @override
  void initState() {
    super.initState();
    _listController = ItemNavigationController(onActivate: _toggleStashDetails);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    for (final controller in _expansionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ExpansibleController _expansionControllerFor(String stashRef) {
    return _expansionControllers.putIfAbsent(
      stashRef,
      ExpansibleController.new,
    );
  }

  /// The keyboard activation of a stash row: toggle its details, exactly
  /// what clicking the row header does.
  void _toggleStashDetails(int index) {
    if (index < 0 || index >= _visibleStashes.length) return;
    final controller = _expansionControllerFor(_visibleStashes[index].ref);
    if (controller.isExpanded) {
      controller.collapse();
    } else {
      controller.expand();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);
    final stashesAsync = ref.watch(stashesProvider);

    if (repositoryPath == null) {
      return const StashesNoRepositoryState();
    }

    final l10n = AppLocalizations.of(context)!;

    // The frame is `chrome.screen`'s (#442). What this screen states is its
    // name, the two things its bar offers and what is on it; the app bar, the
    // spacing between its actions and the arrangement around the body are the
    // skin's answers, exactly as `StandardAppBar` and the raw `Scaffold` used
    // to answer them here.
    return SkinScope.render(
      context,
      (Skin skin, BuildContext inner) => skin.chrome.screen(
        inner,
        ScreenSpec(
          title: AppDestination.stashes.label(context),
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarActionEntry(
                icon: IconRole.arrowsClockwise,
                label: l10n.refresh,
                tooltip: l10n.refresh,
                onPressed: () => ref.read(gitActionsProvider).refreshStashes(),
              ),
              ToolbarMenuEntry(
                icon: IconRole.dotsThreeVertical,
                tooltip: l10n.moreActions,
                entries: [
                  // Create action always first
                  MenuAction(
                    icon: IconRole.plus,
                    label: l10n.createStash,
                    onPressed: () => _showCreateStashDialog(context),
                  ),
                  const MenuSeparator(),
                  // Clear All action. It states its ROLE - this entry destroys
                  // something - and the skin decides what a destructive row
                  // looks like; `Tone.danger` was the application deciding
                  // that itself.
                  MenuAction(
                    icon: IconRole.trash,
                    label: l10n.clearAll,
                    role: MenuActionRole.destructive,
                    onPressed: () => _confirmClearAllStashes(context),
                  ),
                ],
              ),
            ]),
          ],
          body: ContentPort(
            ScreenBodyHost(
              child: BaseInset(
                all: Inset.roomy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: stashesAsync.when(
                        data: (stashes) => _buildStashList(context, stashes),
                        loading: () => const BaseProgress.block(),
                        error: (error, stack) =>
                            StashesErrorState(error: error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

    _visibleStashes = filteredStashes;
    _listController.scheduleInitialHighlight();

    return Column(
      children: [
        // Search bar - always show to match branches/tags screens; arrows
        // hand off to the list while typing continues in the field.
        InlineSearchField(
          controller: _searchController,
          hintText: AppLocalizations.of(context)!.hintTextSearchStashes,
          navigationController: _listController,
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

        // Stash list: one Tab stop with a roving highlight; Enter toggles
        // the highlighted stash's details.
        Expanded(
          child: filteredStashes.isEmpty
              ? Center(
                  child: BaseLabel(
                    'No stashes match "$_searchQuery"',
                    role: TextRole.body,
                  ),
                )
              : KeyboardNavigableListView(
                  controller: _listController,
                  itemCount: filteredStashes.length,
                  autofocus: true,
                  itemBuilder: (context, index, isSelected, containerHasFocus) {
                    final stash = filteredStashes[index];
                    return StashListTile(
                      stash: stash,
                      isHighlighted: isSelected,
                      containerHasFocus: containerHasFocus,
                      expansionController: _expansionControllerFor(stash.ref),
                      // A pointer toggle moves the highlight to the row it
                      // acted on, so keyboard and mouse stay in one story.
                      onExpansionChanged: (_) => _listController.select(index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateStashDialog(BuildContext context) async {
    final result = await Overlays.dialogFrom<Map<String, dynamic>>(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.createStashDialog,
      ),
      builder: (context) => const CreateStashDialog(),
    );

    if (result != null && context.mounted) {
      final message = result['message'] as String;
      final includeUntracked = result['includeUntracked'] as bool;
      final keepIndex = result['keepIndex'] as bool;
      final stashAllFiles = result['stashAllFiles'] as bool;
      final selectedFiles = result['selectedFiles'] as List<String>;

      try {
        await ref
            .read(gitActionsProvider)
            .createStash(
              message: message.isEmpty ? null : message,
              includeUntracked: includeUntracked,
              keepIndex: keepIndex,
              files: stashAllFiles ? null : selectedFiles,
            );

        if (context.mounted) {
          context.showSuccessIfMounted(
            AppLocalizations.of(context)!.stashCreatedSuccess,
          );
        }
      } catch (e) {
        // Staying silent on a failed stash lets the user discard a working
        // tree whose changes were never saved.
        if (context.mounted) {
          context.showErrorIfMounted(
            AppLocalizations.of(context)!.createStashError(e.toString()),
          );
        }
      }
    }
  }

  Future<void> _confirmClearAllStashes(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.clearStashes,
      icon: IconRole.warningCircle,
      title: l10n.clearAllStashesDialog,
      message: l10n.clearAllStashesConfirm,
      confirmLabel: l10n.clearAll,
    );

    if (confirmed && context.mounted) {
      try {
        await ref.read(gitActionsProvider).clearStashes();
        if (context.mounted) {
          context.showSuccessIfMounted(
            AppLocalizations.of(context)!.allStashesClearedSuccess,
          );
        }
      } catch (e) {
        if (context.mounted) {
          context.showErrorIfMounted(
            AppLocalizations.of(context)!.clearStashesError(e.toString()),
          );
        }
      }
    }
  }
}
