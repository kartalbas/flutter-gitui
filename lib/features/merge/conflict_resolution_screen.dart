import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/merge_conflict.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_list_item.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_icon.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_layout.dart';
import '../../shared/controllers/item_navigation_controller.dart';
import '../../shared/widgets/base_dismiss_scope.dart';
import '../../shared/widgets/base_focus_region.dart';
import '../../shared/widgets/keyboard_navigable_view.dart';

/// Screen for resolving merge conflicts.
///
/// Resolving a merge is a per-file decision loop, which is exactly the work a
/// keyboard should carry, so the screen is two focus regions the keyboard owns
/// end to end (#290): the conflicted-file list holds initial focus and its
/// arrows move the highlight while the details pane follows, Enter hands the
/// keyboard to the resolution pane, arrows there walk the choices the selected
/// conflict offers and Enter applies the highlighted one. F6/Shift+F6 cycle
/// between the two panes, and Escape climbs back out — first from the
/// resolution pane to the file list, then off the screen.
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  /// The conflicted-file list's keyboard semantics, in delegated mode: the
  /// selection lives in [_selectedConflict], which the details pane reads so
  /// the resolution this screen just applied stays visible, so the controller
  /// stores no index of its own. Every move writes that one field and every
  /// read asks it, which is what keeps the roving highlight, the details pane
  /// and a click on a row from drifting into three disagreeing selections.
  late final ItemNavigationController _conflictController;

  /// The resolution pane's keyboard semantics: the highlight roves over the
  /// choices the selected conflict offers and Enter applies the highlighted
  /// one. Its selection is a pane-local ordinal with nowhere else to live, so
  /// this controller keeps it itself.
  late final ItemNavigationController _resolutionController;

  /// Lets Enter on a conflicted file hand the keyboard to the resolution pane,
  /// the same handoff history's commit list makes into its details region.
  final GlobalKey<BaseFocusRegionState> _resolutionRegionKey =
      GlobalKey<BaseFocusRegionState>();

  MergeConflict? _selectedConflict;
  bool _isResolving = false;
  String? _errorMessage;

  /// The conflicts the left pane currently lists, in list order, so a keyboard
  /// activation resolves its index against exactly what the user sees.
  List<MergeConflict> _visibleConflicts = const [];

  /// The resolution choices the right pane currently offers, in the order it
  /// renders them — the same contract as [_visibleConflicts].
  List<ResolutionChoice> _visibleChoices = const [];

  @override
  void initState() {
    super.initState();
    _conflictController = ItemNavigationController(
      readIndex: _readSelectedConflictIndex,
      writeIndex: _writeSelectedConflictIndex,
      onActivate: (_) => _resolutionRegionKey.currentState?.focusFirstChild(),
    );
    _resolutionController = ItemNavigationController(
      onActivate: _applyHighlightedResolution,
    );
  }

  @override
  void dispose() {
    _conflictController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  /// Where the highlight sits in the file list. With nothing chosen yet the
  /// first conflict is the answer, so the details pane has something to show
  /// and "N arrows then Enter" counts from the first file.
  int _readSelectedConflictIndex() {
    final selected = _selectedConflict;
    if (selected != null) {
      final index = _visibleConflicts.indexOf(selected);
      if (index >= 0) return index;
    }
    return _visibleConflicts.isEmpty ? -1 : 0;
  }

  void _writeSelectedConflictIndex(int index) {
    if (index < 0 || index >= _visibleConflicts.length) return;
    setState(() {
      _selectedConflict = _visibleConflicts[index];
      // The error belongs to the file that failed, so carrying it over to the
      // next file would accuse a file that was never touched.
      _errorMessage = null;
    });
    // A different file offers a different set of choices; clearing the
    // resolution highlight makes the pane start over at its first option
    // instead of pointing at whatever ordinal the previous file left behind.
    _resolutionController.select(-1);
  }

  /// The keyboard activation of a resolution row: apply that choice to the
  /// highlighted conflict, exactly what clicking the row does.
  ///
  /// The conflict comes from the file list's highlight rather than from
  /// [_selectedConflict], because the highlight starts on the first file
  /// without anything having been chosen yet — reading the remembered field
  /// here would make the very first resolution of a session do nothing.
  void _applyHighlightedResolution(int index) {
    if (_isResolving) return;
    if (index < 0 || index >= _visibleChoices.length) return;
    final conflictIndex = _conflictController.selectedIndex;
    if (conflictIndex < 0 || conflictIndex >= _visibleConflicts.length) return;
    _resolveConflict(_visibleConflicts[conflictIndex], _visibleChoices[index]);
  }

  /// Escape climbs one level out at a time: from the resolution pane it hands
  /// the keyboard back to the file list without choosing anything, and from
  /// the file list it leaves the screen. A resolution is written to git before
  /// the pane ever shows it as resolved, so no level of this ladder can
  /// discard one — and while a resolution is in flight the whole ladder is
  /// disabled (see the scope's `enabled`), so Escape cannot walk out from
  /// under a running git command either.
  void _dismiss() {
    if (_resolutionController.focusNode.hasFocus) {
      _conflictController.requestFocus();
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// The resolution choices [conflict] offers, in pane order. Keeping both
  /// sides only makes sense where both sides have content to keep.
  List<ResolutionChoice> _choicesFor(MergeConflict conflict) => [
    ResolutionChoice.ours,
    ResolutionChoice.theirs,
    if (conflict.type == ConflictType.bothAdded ||
        conflict.type == ConflictType.bothModified)
      ResolutionChoice.both,
  ];

  @override
  Widget build(BuildContext context) {
    final mergeState = ref.watch(mergeStateProvider).value;

    if (mergeState == null || !mergeState.isInProgress) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.mergeConflicts),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The hero glyph of a state that fills this screen. It stays a
              // raw `Icon`: `ControlScale`'s largest rung is the ordinary size
              // of a control's mark, and the artwork that fills an empty
              // region is a different order of thing, so naming the nearest
              // rung would shrink this to a toolbar glyph.
              Icon(
                PhosphorIconsRegular.checkCircle,
                size: 64,
                color: context.gitColors.added,
              ),
              // A hero glyph and the headline under it are two groups inside
              // one region: `separate`.
              const BaseGap(Proximity.separate),
              BaseLabel(
                AppLocalizations.of(context)!.dialogTitleNoMergeInProgress,
                role: TextRole.pageTitle,
              ),
            ],
          ),
        ),
      );
    }

    final conflicts = mergeState.conflicts;
    _visibleConflicts = conflicts;

    // One resolution of the selection feeds the highlight, the details pane
    // and every action, so none of them can act on a file the user is not
    // looking at. The remembered conflict is preferred because it carries the
    // resolution this screen just applied, but only while it still names the
    // file the highlight points at.
    final selectedIndex = _conflictController.selectedIndex;
    final MergeConflict? selectedConflict;
    if (selectedIndex < 0 || selectedIndex >= conflicts.length) {
      selectedConflict = null;
    } else {
      final remembered = _selectedConflict;
      selectedConflict =
          remembered != null && remembered == conflicts[selectedIndex]
          ? remembered
          : conflicts[selectedIndex];
    }

    return BaseDismissScope(
      // While a resolution runs there is nothing to leave: the git command is
      // already on its way and the pane must stay put until it lands.
      enabled: !_isResolving,
      onDismiss: _dismiss,
      child: BaseFocusRegionHost(
        debugLabel: 'ConflictResolutionScreen.regions',
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              AppLocalizations.of(context)!.dialogTitleResolveConflicts(
                mergeState.mergingBranch ?? "branch",
              ),
            ),
            actions: [
              // Abort merge button
              BaseIconButton(
                icon: IconRole.xCircle,
                onPressed: _isResolving
                    ? null
                    : () => _showAbortDialog(context),
                tooltip: AppLocalizations.of(context)!.tooltipAbortMerge,
              ),
              const BaseGap(Proximity.related),
            ],
          ),
          body: conflicts.isEmpty
              ? _buildNoConflicts(context, mergeState)
              : Row(
                  children: [
                    // Conflict list (left panel) - the screen's first focus
                    // region, and the pane that holds initial focus.
                    BaseFocusRegion(
                      order: 1,
                      debugLabel: 'ConflictResolutionScreen.conflictListRegion',
                      child: SizedBox(
                        width: 300,
                        child: _buildConflictList(context, conflicts),
                      ),
                    ),
                    // Not `BaseSeparator`: the pane rule at `width: 1` is a
                    // measurement - it takes no layout space, so the panes
                    // meet - which the separator member deliberately does not
                    // carry. It leaves with the split-pane member.
                    const VerticalDivider(width: 1),

                    // Conflict details (right panel)
                    Expanded(
                      child: BaseFocusRegion(
                        key: _resolutionRegionKey,
                        order: 2,
                        debugLabel: 'ConflictResolutionScreen.resolutionRegion',
                        child: selectedConflict != null
                            ? _buildConflictDetails(context, selectedConflict)
                            : Center(
                                child: BaseLabel(
                                  AppLocalizations.of(
                                    context,
                                  )!.dialogContentSelectConflict,
                                  role: TextRole.body,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar:
              mergeState.unresolvedCount == 0 && conflicts.isNotEmpty
              ? BaseFocusRegion(
                  order: 3,
                  debugLabel: 'ConflictResolutionScreen.continueBarRegion',
                  child: _buildContinueBar(context, mergeState),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildConflictList(
    BuildContext context,
    List<MergeConflict> conflicts,
  ) {
    return Column(
      children: [
        // Header
        Container(
          // The header's fill stays: it is the surface, and the surface leaves
          // with its member. How far it holds its content off its own edge is
          // the language's question - `Inset.normal`.
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: BaseInset(
            child: Row(
              children: [
                const BaseIcon(IconRole.warning),
                const BaseGap(Proximity.related),
                Expanded(
                  child: BaseLabel(
                    AppLocalizations.of(context)!.conflictsToResolve(
                      conflicts.where((c) => !c.isResolved).length,
                    ),
                    role: TextRole.sectionTitle,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Conflict list: one Tab stop with a roving highlight; arrows move
        // between conflicted files and Enter hands the keyboard to the
        // resolution pane for the highlighted one.
        Expanded(
          child: KeyboardNavigableListView(
            controller: _conflictController,
            itemCount: conflicts.length,
            autofocus: true,
            itemBuilder: (context, index, isSelected, containerHasFocus) {
              final conflict = conflicts[index];

              return BaseListItem(
                isSelected: isSelected,
                containerHasFocus: containerHasFocus,
                leading: Icon(
                  conflict.isResolved
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.fileText,
                  color: conflict.isResolved
                      ? context.gitColors.added
                      : context.gitColors.modified,
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Neither the weight nor the strike-through is written
                    // here any more, and both absences are the point. "This
                    // row is the one you are acting on" is the row's own
                    // selection state, which BaseListItem already carries;
                    // "this conflict is dealt with" is Tone.muted, and
                    // whether a design language answers that by striking the
                    // text through is the language's answer, not a screen's.
                    BaseLabel(
                      conflict.fileName,
                      role: TextRole.body,
                      tone: conflict.isResolved ? Tone.muted : Tone.neutral,
                    ),
                    BaseLabel(conflict.typeDisplay, role: TextRole.detail),
                  ],
                ),
                trailing: conflict.isResolved
                    ? Icon(
                        PhosphorIconsRegular.check,
                        color: context.gitColors.added,
                      )
                    : null,
                // A click moves the same highlight the arrows move, so the
                // pointer and the keyboard tell one story.
                onTap: () => _conflictController.select(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConflictDetails(BuildContext context, MergeConflict conflict) {
    final choices = _choicesFor(conflict);
    _visibleChoices = choices;
    _resolutionController.scheduleInitialHighlight();

    return Column(
      children: [
        // File header
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: BaseInset(
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.fileText),
                const BaseGap(Proximity.related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(conflict.filePath, role: TextRole.itemTitle),
                      BaseLabel(conflict.typeDisplay, role: TextRole.detail),
                    ],
                  ),
                ),
                if (conflict.isResolved) ...[
                  Icon(
                    PhosphorIconsRegular.checkCircle,
                    color: context.gitColors.added,
                  ),
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(context)!.resolved,
                    role: TextRole.micro,
                  ),
                ],
              ],
            ),
          ),
        ),

        // The banner used to say one four-sided number: generous on three
        // sides and nothing below. Said as what it is, that is two
        // statements - the header above and the banner are two groups inside
        // one region, and the banner itself is inset from the pane's sides.
        // No per-side rung is minted for it; that would be the token bag
        // returning one side at a time.
        if (_errorMessage != null) ...<Widget>[
          const BaseGap(Proximity.separate),
          BaseInset(
            x: Inset.roomy,
            y: Inset.none,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  children: [
                    // The banner's mark keeps its `Color`. `Tone` has a word
                    // for something that destroys, one for a doubt and one
                    // for a value the user must correct, and none of the
                    // three is "the command you asked for came back with an
                    // error" - which is what this banner says. The label
                    // beside it already reaches for `danger`; the mark does
                    // not follow it there, so the gap stays visible.
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        _errorMessage!,
                        role: TextRole.body,
                        tone: Tone.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // The same restatement: a section apart from what precedes it, inset
        // from the pane's sides, and one group's distance from the choices it
        // introduces.
        const BaseGap(Proximity.separate),
        BaseInset(
          x: Inset.roomy,
          y: Inset.none,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaseLabel(
              AppLocalizations.of(
                context,
              )!.dialogContentChooseResolutionStrategy,
              role: TextRole.sectionTitle,
            ),
          ),
        ),
        const BaseGap(Proximity.grouped),

        // Resolution options: one Tab stop with a roving highlight; arrows
        // walk the choices and Enter applies the highlighted one. The manual
        // resolution note and the progress indicator ride along as a trailing
        // row so the highlight never rests on them.
        Expanded(
          child: KeyboardNavigableListView(
            controller: _resolutionController,
            itemCount: choices.length,
            // The same inset from the pane's sides the two blocks above take,
            // said as a number because it is the scroll view's own content
            // padding: `KeyboardNavigableListView` takes `EdgeInsets`, and a
            // `BaseInset` around the list would inset the viewport rather
            // than its contents.
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingL),
            itemBuilder: (context, index, isSelected, containerHasFocus) =>
                _buildResolutionOption(
                  context,
                  choice: choices[index],
                  index: index,
                  isHighlighted: isSelected,
                  containerHasFocus: containerHasFocus,
                ),
            trailing: _buildResolutionFooter(context),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionOption(
    BuildContext context, {
    required ResolutionChoice choice,
    required int index,
    required bool isHighlighted,
    required bool containerHasFocus,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final String title;
    final String subtitle;
    final IconData icon;
    switch (choice) {
      case ResolutionChoice.theirs:
        title = l10n.acceptTheirs;
        subtitle = l10n.useVersionFromMergingBranch;
        icon = PhosphorIconsRegular.arrowRight;
      case ResolutionChoice.both:
        title = l10n.acceptBoth;
        subtitle = l10n.keepBothVersionsConcatenated;
        icon = PhosphorIconsRegular.arrowsLeftRight;
      case ResolutionChoice.ours:
      case ResolutionChoice.base:
      case ResolutionChoice.manual:
        title = l10n.acceptOurs;
        subtitle = l10n.useVersionFromCurrentBranch;
        icon = PhosphorIconsRegular.arrowLeft;
    }

    return BaseListItem(
      isSelected: isHighlighted,
      containerHasFocus: containerHasFocus,
      // A resolution already on its way to git must not be joined by a second
      // one, so the rows stop responding until it lands.
      isSelectable: !_isResolving,
      leading: Icon(icon),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseLabel(title, role: TextRole.itemTitle),
          BaseLabel(subtitle, role: TextRole.detail),
        ],
      ),
      trailing: const Icon(PhosphorIconsRegular.arrowRight),
      // A click moves the same highlight the arrows move and then applies it,
      // so pointer and keyboard share one selection model.
      onTap: () {
        _resolutionController.select(index);
        _applyHighlightedResolution(index);
      },
    );
  }

  Widget _buildResolutionFooter(BuildContext context) {
    return BaseInset(
      all: Inset.roomy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Manual resolution info
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: BaseInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BaseIcon(IconRole.info),
                      const BaseGap(Proximity.related),
                      BaseLabel(
                        AppLocalizations.of(context)!.manualResolution,
                        role: TextRole.sectionTitle,
                      ),
                    ],
                  ),
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(
                      context,
                    )!.dialogContentManualResolutionInfo,
                    role: TextRole.detail,
                  ),
                ],
              ),
            ),
          ),

          if (_isResolving) ...[
            const BaseGap(Proximity.separate),
            const Center(child: CircularProgressIndicator()),
            const BaseGap(Proximity.related),
            // Still a hand-built style, and the italic is why. `TextRole` says
            // what a line is FOR and `Tone` says what it MEANS; neither says
            // "set this apart as provisional", which is the whole of what the
            // italic is doing on a line that exists only while a git command
            // is in flight. Moving the colour alone would take the italic with
            // it, so the read stays until there is a word for the slant.
            Center(
              child: Text(
                AppLocalizations.of(context)!.resolvingConflict,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoConflicts(BuildContext context, MergeState mergeState) {
    return Center(
      // An empty state is a deliberately generous surface: `Inset.roomy`.
      // This one and every comparable empty state in the application used to
      // say that meaning with two different numbers; naming it settles both
      // on the skin's single answer.
      child: BaseInset(
        all: Inset.roomy,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The same hero glyph as the no-merge state above, and it stays
            // a literal for the same reason: no rung is the size of an empty
            // region's artwork.
            Icon(
              PhosphorIconsRegular.checkCircle,
              size: 64,
              color: context.gitColors.added,
            ),
            const BaseGap(Proximity.separate),
            BaseLabel(
              AppLocalizations.of(context)!.allConflictsResolved,
              role: TextRole.pageTitle,
            ),
            // The headline and the sentence explaining it are two parts of
            // one statement: `related`, exactly as in every other empty state
            // of the application.
            const BaseGap(Proximity.related),
            // The explanation under an empty or error state's headline is
            // ordinary prose — the headline above is what stands out — so it
            // is `body` here exactly as it is in every other empty state of
            // the application. Reading its old size as "this must stand out"
            // and answering with a weight put two contradictory statements on
            // one line wherever the same site also said "secondary".
            BaseLabel(
              AppLocalizations.of(
                context,
              )!.dialogContentAllMergeConflictsResolved,
              role: TextRole.body,
              align: TextAlign.center,
            ),
            // The verbal statement and the actions offered under it are two
            // groups inside the one empty-state region: `separate`, the word
            // every other empty state uses at this boundary. It is not
            // `sectioned` - a message and its own call to action are not two
            // regions about different subjects.
            const BaseGap(Proximity.separate),
            BaseButton(
              label: AppLocalizations.of(context)!.continueMerge,
              variant: ButtonVariant.primary,
              leadingIcon: IconRole.check,
              onPressed: () => _continueMerge(context),
            ),
            // Sibling actions in one run are members of one group:
            // `grouped`, the vocabulary's own exemplar for a run of actions.
            const BaseGap(Proximity.grouped),
            BaseButton(
              label: AppLocalizations.of(context)!.abortMerge,
              variant: ButtonVariant.tertiary,
              leadingIcon: IconRole.xCircle,
              onPressed: () => _showAbortDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueBar(BuildContext context, MergeState mergeState) {
    return Container(
      decoration: BoxDecoration(
        color: context.gitColors.added.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: BaseInset(
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.checkCircle,
              color: context.gitColors.added,
            ),
            const BaseGap(Proximity.grouped),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BaseLabel(
                    AppLocalizations.of(context)!.allConflictsResolved,
                    role: TextRole.sectionTitle,
                  ),
                  BaseLabel(
                    AppLocalizations.of(context)!.readyToContinueMerge,
                    role: TextRole.detail,
                  ),
                ],
              ),
            ),
            BaseButton(
              label: AppLocalizations.of(context)!.continueMerge,
              variant: ButtonVariant.primary,
              leadingIcon: IconRole.check,
              onPressed: () => _continueMerge(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveConflict(
    MergeConflict conflict,
    ResolutionChoice choice,
  ) async {
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(gitActionsProvider)
          .resolveConflict(conflict.filePath, choice: choice);

      if (mounted) {
        setState(() {
          _isResolving = false;
          // Update selected conflict to show it's resolved
          _selectedConflict = conflict.copyWith(
            isResolved: true,
            resolutionChoice: choice,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToResolveConflict(e.toString());
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _continueMerge(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: IconRole.gitMerge,
        title: AppLocalizations.of(context)!.dialogTitleContinueMerge,
        onSubmit: () => Navigator.of(context).pop(true),
        content: BaseLabel(
          AppLocalizations.of(context)!.dialogContentContinueMerge,
          role: TextRole.body,
        ),
        actions: [
          DialogAction(
            label: AppLocalizations.of(context)!.cancel,
            role: DialogActionRole.dismissive,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogAction(
            label: AppLocalizations.of(context)!.dialogActionContinue,
            role: DialogActionRole.affirmative,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(gitActionsProvider).continueMerge();

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToContinueMerge(e.toString());
        });
      }
    }
  }

  Future<void> _showAbortDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: IconRole.warning,
        title: AppLocalizations.of(context)!.dialogTitleAbortMerge,
        content: BaseLabel(
          AppLocalizations.of(context)!.dialogContentAbortMerge,
          role: TextRole.body,
        ),
        actions: [
          DialogAction(
            label: AppLocalizations.of(context)!.cancel,
            role: DialogActionRole.dismissive,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          // Aborting the merge throws away every conflict already resolved.
          DialogAction(
            label: AppLocalizations.of(context)!.dialogTitleAbortMerge,
            role: DialogActionRole.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(gitActionsProvider).abortMerge();

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.snackbarMergeAborted),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToAbortMerge(e.toString());
        });
      }
    }
  }
}
