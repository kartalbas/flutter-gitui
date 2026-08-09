import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_badge.dart';
import '../components/base_icon.dart';
import '../components/base_layout.dart';
import '../components/base_menu_item.dart';
import '../components/base_switcher.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../components/base_label.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/destructive_action.dart';
import '../../core/git/models/branch.dart';
import '../../core/services/notification_service.dart';
import '../dialogs/confirm_destructive.dart';
import '../../features/branches/dialogs/delete_branch_dialog.dart';
import '../../features/branches/dialogs/rename_branch_dialog.dart';
import '../../core/config/app_config.dart';

/// Branch switcher widget - displays current branch and allows switching
class BranchSwitcher extends ConsumerWidget {
  const BranchSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranchAsync = ref.watch(currentBranchProvider);
    final localBranchesAsync = ref.watch(localBranchesProvider);
    final gitService = ref.watch(gitServiceProvider);

    // Only show if there's an active repository
    if (gitService == null) {
      return const SizedBox.shrink();
    }

    final branchName = currentBranchAsync.when(
      data: (branch) {
        if (branch != null) return branch;
        final l10n = AppLocalizations.of(context)!;
        return l10n.noBranchAvailable;
      },
      loading: () => 'Loading...',
      error: (_, _) => 'Error',
    );

    final branches = localBranchesAsync.value ?? [];

    return BaseSwitcher(
      icon: PhosphorIconsBold.gitBranch,
      label: branchName,
      tooltip: branches.length > 1
          ? AppLocalizations.of(context)!.tooltipSwitchBranch
          : branchName,
      showDropdown: branches.length > 1,
      onTap: branches.length > 1
          ? () => _showBranchMenu(context, ref, branches)
          : null,
    );
  }

  void _showBranchMenu(
    BuildContext context,
    WidgetRef ref,
    List<GitBranch> branches,
  ) {
    final l10n = AppLocalizations.of(context)!;

    // Check animation speed setting
    final animationSpeed =
        Theme.of(context).extension<AnimationSpeedExtension>()?.speed ??
        AppAnimationSpeed.normal;

    // Sort branches: protected branches first, then by name
    final sortedBranches = List<GitBranch>.from(branches)
      ..sort((a, b) {
        // Protected branches come first
        if (a.isProtected && !b.isProtected) return -1;
        if (!a.isProtected && b.isProtected) return 1;
        // Within same protection level, sort alphabetically
        return a.name.compareTo(b.name);
      });

    // Check if there are any deletable branches (non-current, non-protected)
    final hasDeletableBranches = sortedBranches.any(
      (b) => !b.isCurrent && !b.isProtected,
    );

    final menuItems = <PopupMenuEntry<dynamic>>[
      // Branch items
      ...sortedBranches.map((branch) {
        final isSelected = branch.isCurrent;
        return PopupMenuItem<GitBranch>(
          value: branch,
          child: Row(
            children: [
              Expanded(
                child: MenuItemContentTwoLine(
                  icon: PhosphorIconsBold.gitBranch,
                  primaryLabel: branch.name,
                  secondaryLabel: branch.lastCommitMessage,
                  // The mark carries the application's own colour, which is a
                  // meaning: `Tone.accent`. The glyph itself stays a Phosphor
                  // Bold constant on this component - its stroke is a fact
                  // `IconRole` cannot carry - but the COLOUR no longer has to
                  // be Material's word for it at this call site.
                  tone: Tone.accent,
                  isSelected: isSelected,
                  showCheck: true,
                ),
              ),
              // Protected branch lock icon
              if (branch.isProtected) ...[
                const BaseIcon(
                  IconRole.lock,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                // The lock and the row actions beside it are two parts of one
                // entry; the trailing padding was that space wearing a padding
                // idiom.
                const BaseGap(Proximity.related),
              ],
              // Action buttons (disabled for protected branches)
              if (!branch.isProtected)
                BaseIconButton(
                  icon: IconRole.pencilSimple,
                  tooltip: l10n.renameBranch(branch.name),
                  size: ButtonSize.small,
                  onPressed: () {
                    Navigator.of(context).pop(); // Close menu
                    _showRenameBranchDialog(context, ref, branch);
                  },
                ),
              if (!isSelected &&
                  !branch
                      .isProtected) // Only show delete for non-current, non-protected branches
                BaseIconButton(
                  icon: IconRole.trash,
                  tooltip: l10n.deleteBranch,
                  size: ButtonSize.small,
                  onPressed: () {
                    Navigator.of(context).pop(); // Close menu
                    _showDeleteBranchDialog(context, ref, branch);
                  },
                ),
            ],
          ),
        );
      }),
      // Add separator and "Delete all except protected" option if there are deletable branches
      if (hasDeletableBranches) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete_all_unprotected',
          child: MenuItemContent(
            icon: IconRole.trash,
            label: l10n.deleteAllUnprotectedBranches,
            tone: Tone.danger,
          ),
        ),
      ],
    ];

    // Show menu with animation duration adapted to settings
    final menuFuture = showMenu<dynamic>(
      context: context,
      position: _getMenuPosition(context),
      items: menuItems,
      popUpAnimationStyle: AnimationStyle(
        duration: AppTheme.getStandardAnimation(animationSpeed),
      ),
    );

    menuFuture.then((result) {
      if (!context.mounted) return;

      if (result is GitBranch && !result.isCurrent) {
        _switchBranch(context, ref, result);
      } else if (result == 'delete_all_unprotected') {
        _showDeleteAllUnprotectedDialog(context, ref, sortedBranches);
      }
    });
  }

  Future<void> _switchBranch(
    BuildContext context,
    WidgetRef ref,
    GitBranch branch,
  ) async {
    try {
      await ref
          .read(gitActionsProvider)
          .switchBranch(branch.name, createIfMissing: false);
    } catch (e) {
      if (!context.mounted) return;
      NotificationService.showError(context, 'Failed to switch branch: $e');
    }
  }

  Future<void> _showDeleteBranchDialog(
    BuildContext context,
    WidgetRef ref,
    GitBranch branch,
  ) async {
    // DeleteBranchDialog returns a DeleteBranchResult (it also collects the
    // force choice), so the old `showDialog<bool>` + `result == true` guard
    // never matched and the delete silently did nothing.
    final result = await showDialog<DeleteBranchResult>(
      context: context,
      builder: (context) => DeleteBranchDialog(branch: branch),
    );
    if (result != null &&
        result != DeleteBranchResult.cancel &&
        context.mounted) {
      try {
        final force = result == DeleteBranchResult.forceDelete;
        // confirmed-by: DeleteBranchDialog above; it collects the force
        // choice and confirms.
        await ref
            .read(gitActionsProvider)
            .deleteBranch(branch.name, force: force);
        if (!context.mounted) return;
        NotificationService.showSuccess(
          context,
          'Branch "${branch.name}" deleted',
        );
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Failed to delete branch: $e');
      }
    }
  }

  Future<void> _showRenameBranchDialog(
    BuildContext context,
    WidgetRef ref,
    GitBranch branch,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => RenameBranchDialog(branch: branch),
    );
    // Dialog returns new branch name if rename was confirmed
    if (result != null && context.mounted) {
      try {
        await ref
            .read(gitActionsProvider)
            .renameBranch(result, oldName: branch.name);
        if (!context.mounted) return;
        NotificationService.showSuccess(
          context,
          'Branch "${branch.name}" renamed to "$result"',
        );
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Failed to rename branch: $e');
      }
    }
  }

  Future<void> _showDeleteAllUnprotectedDialog(
    BuildContext context,
    WidgetRef ref,
    List<GitBranch> branches,
  ) async {
    // Get list of deletable branches
    final deletableBranches = branches
        .where((b) => !b.isCurrent && !b.isProtected)
        .toList();

    if (deletableBranches.isEmpty) return;

    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    // The dialog states which branches it will keep before the user presses
    // anything, so this has to be git's own answer to "would `git branch -d`
    // take this one" - see getBranchesDeletableWithoutForce, which reproduces
    // git's rule (upstream when the branch tracks one, HEAD otherwise) rather
    // than approximating it with `git branch --merged`.
    final Set<String> deletableWithoutForce;
    try {
      deletableWithoutForce =
          (await gitService.getBranchesDeletableWithoutForce()).unwrap();
    } catch (e) {
      if (!context.mounted) return;
      NotificationService.showError(
        context,
        'Failed to determine merged branches: $e',
      );
      return;
    }

    if (!context.mounted) return;

    final result = await showDialog<BulkDeleteResult>(
      context: context,
      builder: (context) => BulkDeleteBranchesDialog(
        branches: deletableBranches,
        deletableWithoutForce: deletableWithoutForce,
      ),
    );

    if (result != null &&
        result.selectedBranches.isNotEmpty &&
        context.mounted) {
      // Deleting branches is reflog-recoverable, so the batch confirmation
      // runs under the master "confirm destructive actions" switch; force
      // deleting adds the unmerged-loss warning to the same prompt.
      final l10n = AppLocalizations.of(context)!;
      final message = l10n.deleteAllUnprotectedBranchesConfirm(
        result.selectedBranches.length,
      );
      final confirmed = await confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteLocalBranch,
        icon: IconRole.trash,
        title: l10n.deleteAllUnprotectedBranches,
        // The bulk phrasing, not `forceDeleteWarning`: that one says "This
        // branch is not fully merged", which is the wrong sentence in front
        // of a list of them.
        message: result.force
            ? '$message\n\n${l10n.forceDeleteBranchesWarning}'
            : message,
        confirmLabel: l10n.deleteAll,
      );
      if (!confirmed || !context.mounted) return;
      await _deleteAllUnprotectedBranches(
        context,
        ref,
        result.selectedBranches,
        force: result.force,
      );
    }
  }

  Future<void> _deleteAllUnprotectedBranches(
    BuildContext context,
    WidgetRef ref,
    List<GitBranch> branches, {
    bool force = false,
  }) async {
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final branch in branches) {
      try {
        // confirmed-by: confirmDestructive(DestructiveAction.deleteLocalBranch)
        // in _showDeleteAllUnprotectedDialog, this method's only caller.
        await ref
            .read(gitActionsProvider)
            .deleteBranch(branch.name, force: force);
        successCount++;
      } catch (e) {
        failCount++;
        errors.add('${branch.name}: $e');
      }
    }

    if (!context.mounted) return;

    // Show summary notification
    if (failCount == 0) {
      NotificationService.showSuccess(
        context,
        'Successfully deleted $successCount branch${successCount == 1 ? '' : 'es'}',
      );
    } else if (successCount == 0) {
      NotificationService.showError(
        context,
        'Failed to delete all branches:\n${errors.join('\n')}',
      );
    } else {
      NotificationService.showWarning(
        context,
        'Deleted $successCount branch${successCount == 1 ? '' : 'es'}, but $failCount failed:\n${errors.join('\n')}',
      );
    }
  }

  RelativeRect _getMenuPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    // Position menu below the button by using bottomLeft instead of topLeft
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        Offset(topLeft.dx, bottomRight.dy), // Start from bottom-left of button
        bottomRight,
      ),
      Offset.zero & overlay.size,
    );
    return position;
  }
}

/// What [BulkDeleteBranchesDialog] reported when it closed: the branches the
/// user ticked, and whether they asked for the unmerged ones to go with them.
///
/// A dismissal reports nothing at all (`null`), so a caller can never mistake
/// "the user said no" for "the user selected nothing".
class BulkDeleteResult {
  const BulkDeleteResult({required this.selectedBranches, required this.force});

  final List<GitBranch> selectedBranches;

  /// Whether the deletion runs as `git branch -D` instead of `git branch -d`,
  /// i.e. whether unmerged branches are destroyed rather than skipped.
  final bool force;
}

/// The confirmation for deleting every unprotected branch at once - the most
/// destructive prompt in the application.
class BulkDeleteBranchesDialog extends StatefulWidget {
  const BulkDeleteBranchesDialog({
    super.key,
    required this.branches,
    required this.deletableWithoutForce,
  });

  /// The deletable branches, in the order they are listed.
  final List<GitBranch> branches;

  /// The branches `git branch -d` accepts, from
  /// [GitService.getBranchesDeletableWithoutForce] - i.e. those whose commits
  /// are already somewhere else, either merged into HEAD or pushed to the
  /// upstream the branch tracks. They wear the `merged` pill.
  ///
  /// Every other branch wears `unmerged`: `git branch -d` refuses it, so an
  /// unforced deletion keeps it, and only a forced deletion removes it - at
  /// the price of leaving the reflog as the sole way back.
  ///
  /// This is git's own rule rather than `git branch --merged`, which is what
  /// the dialog used to be handed and which disagrees with `-d` in both
  /// directions; the dialog promises the user which branches it will keep, so
  /// the promise has to be the one git honours.
  final Set<String> deletableWithoutForce;

  /// The checkbox of one branch row, so a caller (and a test) can address a
  /// named branch rather than the n-th checkbox on screen.
  static Key checkboxKeyFor(String branchName) =>
      Key('bulk-delete-branch-$branchName');

  /// The explicit force opt-in.
  static const Key forceCheckboxKey = Key('bulk-delete-force');

  @override
  State<BulkDeleteBranchesDialog> createState() =>
      _BulkDeleteBranchesDialogState();
}

class _BulkDeleteBranchesDialogState extends State<BulkDeleteBranchesDialog> {
  late Map<String, bool> _selectedBranches;

  // One delete action with force as an explicit opt-in, rather than the
  // "Delete Selected" and "Force Delete Selected" buttons that used to sit
  // next to each other.
  //
  // The two buttons differed by one word and by nothing else - same row, same
  // danger colour, same single click - which put `git branch -D`, which
  // discards commits and leaves the reflog as the only way back, exactly one
  // button-width away from `git branch -d`, which refuses to lose anything. A
  // slip between two adjacent buttons is not a decision, and this is the
  // dialog where a slip costs the most.
  //
  // The pair also hid the thing the user most needs to know. Under `-d` every
  // unmerged branch in the selection simply fails, and neither button said
  // so: the user pressed "Delete Selected" with eight branches ticked and
  // learned only from the summary notification afterwards that three of them
  // were still there. With one action the dialog can state that up front -
  // how many ticked branches are unmerged and will be kept - and this
  // checkbox is the answer to exactly that sentence, sitting beside it in the
  // content instead of in the action row. It is therefore shown only while
  // that sentence is on screen (see the content below): with nothing unmerged
  // in the selection, `-D` and `-d` do the same thing and the only effect a
  // force checkbox could have is on a later selection.
  //
  // It is also what the single-branch delete already does
  // (lib/features/branches/dialogs/delete_branch_dialog.dart, where force is a
  // checkbox and the confirm button relabels itself). The bulk delete is
  // strictly the more dangerous of the two, so it cannot be the one that is
  // less deliberate.
  bool _force = false;

  @override
  void initState() {
    super.initState();
    // Initialize all branches as checked
    _selectedBranches = {for (var branch in widget.branches) branch.name: true};
  }

  int get _selectedCount =>
      _selectedBranches.values.where((selected) => selected).length;

  /// How many ticked branches `git branch -d` would refuse - the branches an
  /// unforced deletion keeps, and the only branches force changes anything
  /// for.
  int get _unmergedSelectedCount => widget.branches
      .where(
        (branch) =>
            _selectedBranches[branch.name] == true &&
            !_isDeletableWithoutForce(branch),
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unmergedSelected = _unmergedSelectedCount;

    return BaseDialog(
      title: l10n.deleteAllUnprotectedBranches,
      icon: IconRole.trash,
      variant: DialogVariant.destructive,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseLabel(
            l10n.branchesSelectedForDeletion(_selectedCount),
            role: TextRole.body,
          ),
          // The count and the list it counts are two parts of one statement.
          const BaseGap(Proximity.related),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: widget.branches.map((branch) {
                  final losesNothing = _isDeletableWithoutForce(branch);
                  // A raw CheckboxListTile, as in the single-branch delete
                  // and the tag delete. The Base* layer has no checkbox row
                  // to reuse yet, and `avoid_list_tile` does not catch this
                  // one because it matches the name ListTile exactly - so
                  // CheckboxListTile, SwitchListTile and ExpansionTile all
                  // pass it. Both halves of that belong in the component
                  // layer, not in this dialog.
                  return CheckboxListTile(
                    key: BulkDeleteBranchesDialog.checkboxKeyFor(branch.name),
                    value: _selectedBranches[branch.name] ?? false,
                    onChanged: (value) => _toggleBranch(branch, value ?? false),
                    title: Row(
                      children: [
                        Expanded(
                          child: BaseLabel(branch.name, role: TextRole.body),
                        ),
                        // The component layer's badge, not a hand-rolled
                        // pill: `BadgeVariant.success` and
                        // `BadgeVariant.danger` are already the green-on-tint
                        // and red-on-tint this needs, and the branches panel
                        // draws its own row badges with the same component
                        // (features/branches/widgets/branch_list_tile.dart).
                        // A copy here would render the same status a little
                        // differently on the same kind of row, and would not
                        // follow the badge when the component changes - which
                        // the golden baselines pin and this dialog does not
                        // appear in.
                        //
                        // It used to ask for `isPill: false` - a 4 dp corner
                        // instead of the badge's own - which is precisely the
                        // "a little differently on the same kind of row" this
                        // comment was written against: the branches panel's
                        // row badge is a pill and this one was not. The corner
                        // is the skin's, and `surfaces.badge` has one shape,
                        // so the flag went with the hand-painted geometry.
                        BaseBadge(
                          label: losesNothing
                              ? l10n.branchStatusMerged
                              : l10n.branchStatusUnmerged,
                          variant: losesNothing
                              ? BadgeVariant.success
                              : BadgeVariant.danger,
                          size: BadgeSize.small,
                        ),
                      ],
                    ),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ),
          // The force opt-in is offered only while it would change something,
          // and then only underneath the sentence that explains it.
          //
          // With every ticked branch already deletable, `-D` and `-d` do
          // exactly the same thing, so a force checkbox there is a control
          // whose only possible effect is on the *next* selection - it arms a
          // mode out of sight. Hiding it also removes the failure this dialog
          // is most exposed to: a row of identical dense checkboxes where the
          // last one, at the same rhythm and one gap below the branches, is
          // the one that arms `git branch -D` over the whole selection.
          if (unmergedSelected > 0) ...[
            // The list of branches and the warning about them are members of
            // one dialog body.
            const BaseGap(Proximity.grouped),
            BaseLabel(
              l10n.unmergedBranchesWillBeSkipped(unmergedSelected),
              role: TextRole.body,
            ),
            // The sentence and the opt-in it explains are one statement, and
            // that closeness is what keeps the checkbox from reading as just
            // another row.
            const BaseGap(Proximity.related),
            _forceOptIn(context, l10n),
          ],
        ],
      ),
      // The dialog now has a way to say no, and still no affirmative action.
      //
      // Escape and the title bar's close button used to be the only exits,
      // which reads as though the deletion had already been decided and the
      // user were only picking a variant of it. Neither delete may become the
      // affirmative action instead: the affirmative one is the action a design
      // language may single out as the dialog's default (Cupertino draws it as
      // the default action, Fluent moves it to the head of the row), and that
      // would make a bulk branch deletion the default. So the dismissive
      // action is the only one with no danger attached, and it is what the eye
      // lands on.
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          // The label states which of the two git commands is about to run,
          // so the force checkbox is never a hidden mode.
          label: _force ? l10n.forceDelete : l10n.delete,
          role: DialogActionRole.destructive,
          enabled: _selectedCount > 0,
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  /// The explicit opt-in to `git branch -D`, deliberately built to be nothing
  /// like the branch rows above it.
  ///
  /// It used to be the same dense [CheckboxListTile] as a branch row, in the
  /// default text colour, 8 dp below a list the user was already clicking
  /// through - so the next checkbox under the cursor, at the same rhythm,
  /// was the one that arms a `-D` over the whole selection. And the only
  /// statement of what force costs appeared *after* it was ticked, i.e. after
  /// the decision.
  ///
  /// So: its own error-tinted, bordered block, a warning glyph, an
  /// error-coloured label, and the consequence spelled out underneath whether
  /// the box is ticked or not. That last part is the important one - the user
  /// reads what force does before choosing it, not as a confirmation of a
  /// choice already made.
  Widget _forceOptIn(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        // The block's own FILL and BORDER, and neither is a foreground: a
        // tint at 8% and a stroke at 40% are how this surface is painted, not
        // what any word on it means. They leave with the surface rather than
        // with the tone vocabulary - the application has no way to resolve
        // `Tone.danger` into a `Color` for a `BoxDecoration`, and the seam is
        // right to withhold one.
        //
        // **Which surface, though, is a contract finding.** The two members
        // that come closest each miss by one thing. `surfaces.banner` says
        // exactly what this block says - *something about this whole surface
        // needs saying* - and cannot hold it: a banner's ways out are
        // `NoticeAction`s, i.e. buttons, and the whole point here is a
        // CHECKBOX the user arms before pressing anything. `surfaces.card`
        // holds the control but drops the warning: the Material member paints
        // `CardSpec.tone` into an unselected card's BORDER only, and takes
        // its fill from `surfaceContainerHigh` regardless - so a
        // `Tone.danger` card at rest is a neutral block with a red outline,
        // and the error wash that makes this thing look nothing like the
        // branch rows above it would simply be gone. Weakening the one
        // affordance standing between the user and a `-D` over a whole
        // selection is not a rendering difference, so the corner stays until
        // a tinted surface can hold a control.
        color: colorScheme.error.withValues(alpha: 0.08),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      // The block is barely set in from its own border: it is a dense
      // checkbox row, not a card.
      child: BaseInset(
        all: Inset.tight,
        // The tile paints its hover, focus and pressed state layers on the
        // nearest Material, so inside a decorated box it needs one of its own
        // or those layers land behind the tint and stay invisible - the same
        // reason BaseCard carries one (shared/components/base_card.dart).
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            key: BulkDeleteBranchesDialog.forceCheckboxKey,
            value: _force,
            onChanged: (value) => setState(() => _force = value ?? false),
            // A checked box painted in the destructive colour, which is the
            // one thing on this row that is not a foreground: it is the
            // control's own fill. `ToggleKind.check` plus `Tone.danger` says
            // it once `controls.toggle` exists; until then a `Color` is the
            // only thing `CheckboxListTile` will take.
            activeColor: colorScheme.error,
            title: Row(
              children: [
                // Left as a Phosphor constant deliberately. This block is
                // built to look nothing like the branch rows above it, and the
                // heavier stroke is part of that treatment - which is a fact
                // `IconRole` cannot carry, because a role names the mark and
                // the skin re-decides its weight. Converting it here would
                // drop the weight silently. See the P3d report.
                //
                // The colour is pinned to that decision: a raw `Icon` takes a
                // `Color` and nothing else, and the application has no way to
                // ask a skin what `Tone.danger` resolves to - by design, since
                // handing out colours is what the seam exists to stop. So the
                // Material read stays for exactly as long as the raw glyph
                // does, and the two convert together or not at all.
                Icon(
                  PhosphorIconsBold.warning,
                  size: AppTheme.iconS,
                  color: colorScheme.error,
                ),
                // The warning mark and the words it qualifies are two halves
                // of one statement.
                const BaseGap(Proximity.related),
                Expanded(
                  child: BaseLabel(
                    l10n.forceDelete,
                    role: TextRole.control,
                    tone: Tone.danger,
                  ),
                ),
              ],
            ),
            subtitle: BaseLabel(
              l10n.forceDeleteBranchesWarning,
              role: TextRole.detail,
              tone: Tone.danger,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ),
    );
  }

  /// Whether `git branch -d` takes this branch as it stands, which is what the
  /// `merged` pill means. See [BulkDeleteBranchesDialog.deletableWithoutForce].
  bool _isDeletableWithoutForce(GitBranch branch) =>
      widget.deletableWithoutForce.contains(branch.name);

  void _toggleBranch(GitBranch branch, bool selected) {
    setState(() {
      _selectedBranches[branch.name] = selected;
      // Unticking the last unmerged branch takes the force opt-in off screen,
      // so it must not stay armed behind it: a ticked-then-hidden checkbox
      // would re-arm `-D` the moment another unmerged branch is ticked again,
      // with nothing on screen saying so.
      if (_unmergedSelectedCount == 0) _force = false;
    });
  }

  void _deleteSelected() {
    final selectedBranches = widget.branches
        .where((branch) => _selectedBranches[branch.name] == true)
        .toList();

    Navigator.of(
      context,
    ).pop(BulkDeleteResult(selectedBranches: selectedBranches, force: _force));
  }
}
