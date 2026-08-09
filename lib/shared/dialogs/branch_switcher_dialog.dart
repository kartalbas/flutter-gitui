import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../../core/services/notification_service.dart';
import '../components/base_dialog.dart';
import '../components/base_list_item.dart';
import '../controllers/item_navigation_controller.dart';
import '../widgets/keyboard_navigable_view.dart';
import '../widgets/search_field_handoff.dart';
import '../components/base_layout.dart';

/// Dialog for switching between git branches (Ctrl+B).
///
/// Fully keyboard operable, the same way the hosted-repository picker is: the
/// search field takes focus on open, the arrow keys move the highlight through
/// the results without leaving the field, and Enter checks the highlighted
/// branch out. It used to offer no keyboard path at all past the filter - the
/// rows were tappable and nothing else - so filtering with the keyboard ended
/// in a reach for the mouse.
class BranchSwitcherDialog extends ConsumerStatefulWidget {
  const BranchSwitcherDialog({super.key});

  @override
  ConsumerState<BranchSwitcherDialog> createState() =>
      _BranchSwitcherDialogState();
}

class _BranchSwitcherDialogState extends ConsumerState<BranchSwitcherDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showRemoteBranches = false;

  /// The result list on the shared navigation semantics: arrows rove its
  /// highlight (from the field via the handoff, or from the list as its own
  /// Tab stop) and activation checks the highlighted branch out.
  late final ItemNavigationController _listController;

  /// The branches currently on screen, refreshed every build, so activation
  /// resolves an index against exactly what the user sees.
  List<GitBranch> _matches = const [];

  /// Height of one result row, for keeping the highlight scrolled into view.
  /// A fixed extent is what lets the list scroll the highlight into view at
  /// all, so it is sized for the tallest row: the branch name plus its last
  /// commit message, plus the list item's own padding.
  static const double _rowExtent = 80;

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
    _switchBranch(_matches[index]);
  }

  /// Enter from anywhere in the dialog takes the highlighted branch, falling
  /// back to the first one while nothing is highlighted yet.
  void _confirm() {
    if (_matches.isEmpty) return;
    final index = _listController.selectedIndex;
    _switchBranch(
      _matches[index < 0 ? 0 : index.clamp(0, _matches.length - 1)],
    );
  }

  /// Restarts the highlight at the first row of a fresh result set - a new
  /// query or the other tab, where the old position would point at an
  /// unrelated branch.
  void _resetHighlight() {
    _listController.select(-1);
    _listController.scheduleInitialHighlight();
  }

  @override
  Widget build(BuildContext context) {
    final localBranchesAsync = ref.watch(localBranchesProvider);
    final remoteBranchesAsync = ref.watch(remoteBranchesProvider);

    _matches = _filtered(
      localBranchesAsync.value ?? const [],
      remoteBranchesAsync.value ?? const [],
    );
    if (_matches.isNotEmpty) {
      // The first match is highlighted from the start, so Enter without any
      // arrow key takes it.
      _listController.scheduleInitialHighlight();
    }

    return BaseDialog(
      // Drawn at Phosphor BOLD before the conversion: same branch mark,
      // heavier stroke. A role carries no weight (#249 conflict C3) and
      // nothing here is a state the skin could re-decide one from, so the
      // header mark now takes the ordinary stroke — the same one the branch
      // mark takes at 53 other sites, including the field prefix two rows
      // below it. Recorded and pinned by
      // `test/shared/icons/icon_weight_census_test.dart`.
      icon: IconRole.gitBranch,
      title: AppLocalizations.of(context)!.switchBranch,
      // Enter checks out the highlighted branch from anywhere in the dialog.
      onSubmit: _matches.isEmpty ? null : _confirm,
      content: Column(
        children: [
          // Arrows typed in the field move the list's highlight and Enter
          // takes the highlighted branch while the caret stays in the field.
          SearchFieldHandoff(
            controller: _listController,
            child: BaseTextField(
              controller: _searchController,
              autofocus: true,
              hintText: AppLocalizations.of(context)!.searchBranches,
              prefixIcon: IconRole.magnifyingGlass,
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _resetHighlight();
              },
            ),
          ),
          const BaseGap(Proximity.grouped),

          // iOS-style toggle for remote branches
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  context,
                  label: AppLocalizations.of(context)!.localTab,
                  isSelected: !_showRemoteBranches,
                  onTap: () {
                    setState(() => _showRemoteBranches = false);
                    _resetHighlight();
                  },
                ),
                _buildToggleButton(
                  context,
                  label: AppLocalizations.of(context)!.remoteTab,
                  isSelected: _showRemoteBranches,
                  onTap: () {
                    setState(() => _showRemoteBranches = true);
                    _resetHighlight();
                  },
                ),
              ],
            ),
          ),
          const BaseGap(Proximity.grouped),

          // Branch list needs an explicit height: BaseDialog wraps the content
          // in a SingleChildScrollView, so a flex child would be unbounded.
          SizedBox(
            height: 400,
            child: localBranchesAsync.when(
              data: (_) {
                if (_matches.isEmpty) {
                  return Center(
                    child: BaseLabel(
                      AppLocalizations.of(context)!.noBranchesFound,
                      role: TextRole.body,
                      tone: Tone.muted,
                    ),
                  );
                }

                // A navigable collection: one Tab stop with the roving
                // highlight the field's handoff drives, kept scrolled into
                // view by the fixed row extent.
                return KeyboardNavigableListView(
                  controller: _listController,
                  itemCount: _matches.length,
                  itemExtent: _rowExtent,
                  itemBuilder:
                      (context, index, isSelected, containerHasFocus) =>
                          _buildRow(_matches[index], isHighlighted: isSelected),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: BaseLabel(
                  AppLocalizations.of(
                    context,
                  )!.errorLoadingBranches(error.toString()),
                  role: TextRole.body,
                  tone: Tone.danger,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // The affirmative action of this dialog is picking a branch from the
        // list (Enter on the highlighted row, see onSubmit above); leaving
        // without picking one is what this button does.
        DialogAction(
          label: AppLocalizations.of(context)!.close,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// The branches the dialog shows, in the order it shows them: the search
  /// filter applied to the visible tab, current branch first.
  List<GitBranch> _filtered(
    List<GitBranch> localBranches,
    List<GitBranch> remoteBranches,
  ) {
    final all = [...localBranches, if (_showRemoteBranches) ...remoteBranches];
    final matches = all.where((branch) {
      if (_searchQuery.isEmpty) return true;
      return branch.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    matches.sort((a, b) {
      if (a.isCurrent && !b.isCurrent) return -1;
      if (!a.isCurrent && b.isCurrent) return 1;
      return a.name.compareTo(b.name);
    });
    return matches;
  }

  Widget _buildRow(GitBranch branch, {required bool isHighlighted}) {
    final isCurrent = branch.isCurrent;
    return BaseListItem(
      // The row the keyboard is on carries the selection styling; the branch
      // that happens to be checked out is marked by its check icon instead,
      // so the two never compete for the same visual.
      isSelected: isHighlighted,
      // The highlight follows the caret in the search field, so it keeps its
      // full strength while the field drives it.
      containerHasFocus: true,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active indicator
          SizedBox(
            width: AppTheme.paddingL,
            // Still a raw mark, and deliberately so: it is drawn at Phosphor
            // BOLD, a role carries no weight (#249 conflict C3), and giving a
            // weight up is a P3a decision recorded in the census ledger rather
            // than a side effect of converting a SIZE. Its `AppTheme.iconS`
            // read therefore survives this phase, named here.
            child: isCurrent
                ? Icon(
                    PhosphorIconsBold.check,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
          const BaseGap(Proximity.related),
          // Remote indicator. The mark used to state its size as
          // `AppTheme.paddingM`, which is the spacing vocabulary standing in
          // for the icon one; what it says is that a row-level mark is dense.
          if (branch.isRemote)
            const BaseIcon(
              IconRole.cloud,
              scale: ControlScale.compact,
              tone: Tone.accent,
            ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseLabel(branch.name, role: TextRole.body),
          if (branch.lastCommitMessage != null)
            BaseLabel(
              branch.lastCommitMessage!,
              role: TextRole.detail,
              maxLines: 1,
            ),
        ],
      ),
      // Survives the tone conversion whole: the glyph is a Phosphor BOLD
      // constant, a weight `IconRole` cannot carry (conflict C3), so
      // converting the colour alone would drop the stroke silently. The
      // accent/muted conditional is the row's is-current state restated on
      // its mark and converts with the weight when the row is a member that
      // draws its own trailing mark.
      trailing: Icon(
        PhosphorIconsBold.gitBranch,
        color: isCurrent
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () => _switchBranch(branch),
    );
  }

  Future<void> _switchBranch(GitBranch branch) async {
    // Don't switch if already on this branch
    if (branch.isCurrent) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      // Checking out a remote branch under its local name lets git create the
      // tracking branch, instead of one literally named "origin/<branch>".
      await ref
          .read(gitActionsProvider)
          .switchBranch(branch.branchNameWithoutRemote);
      // Close only after success, so a failure can still be reported here.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          AppLocalizations.of(context)!.failedToSwitchBranch(e.toString()),
        );
      }
    }
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // The chosen segment's FILL, not a foreground: this is what the
          // segment is painted in, and the word below is paired against it.
          // It leaves with `controls.choiceGroup`, the member that owns a
          // segmented control's selected surface.
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        // The chosen segment is painted in the accent, so its word is the
        // foreground that goes ON the accent; the segment beside it is present
        // but secondary to the one that is chosen. Those are the two meanings
        // `onPrimary` and `onSurfaceVariant` were Material's answers to, and
        // the word carries them itself now instead of being handed a
        // `TextStyle` from outside. The semibold that used to sit here was a
        // second statement of the same selection the fill already makes.
        //
        // The segment is dense, which is all Inset.tight says; it used to say
        // `AppTheme.paddingS + AppTheme.paddingXS` across, which is the
        // application doing arithmetic on a token and therefore deciding a
        // length itself. This whole control is `controls.choiceGroup` once
        // that member lands, and the rung goes with it.
        child: BaseInset(
          all: Inset.tight,
          child: BaseLabel(
            label,
            role: TextRole.control,
            tone: isSelected ? Tone.onAccent : Tone.muted,
          ),
        ),
      ),
    );
  }
}
