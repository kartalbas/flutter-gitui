import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state when repository has no commits
class NoCommitsState extends StatelessWidget {
  const NoCommitsState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The hero mark's size is no longer written here, and that is the whole
    // point of adopting the facade (#430): `EmptyStateSpec` takes an icon, a
    // headline, a sentence and the ways out, and NO size - a member that
    // accepts no size owns the size, so a `64` at this call site was a leak by
    // construction rather than a number waiting for a rung. `ControlScale`
    // never was the answer: it asks how much room a CONTROL's mark is entitled
    // to and tops out at 24, so naming its loudest rung would have shrunk this
    // glyph to a third and turned an empty state into a blank one.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.gitCommit,
      title: l10n.emptyStateNoCommits,
      message: l10n.emptyStateNoCommitsMessage,
    );
  }
}

/// Empty state showing error when loading history fails
class HistoryErrorState extends StatelessWidget {
  final Object error;

  const HistoryErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // The one shape in this file the facade cannot take, and the blocker is
    // the mark's COLOUR rather than its size. `EmptyStateWidget` paints its
    // hero in the supporting foreground unconditionally and carries no tone
    // slot, so adopting it here would silently turn a red failure mark grey -
    // the whole difference between "there is nothing here" and "this went
    // wrong" - which is a change of appearance rather than a rename. Reported
    // instead: the facade needs a tone on its hero before this converts.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const BaseGap(Proximity.separate),
          const BaseLabel('Error Loading History', role: TextRole.pageTitle),
          const BaseGap(Proximity.related),
          BaseLabel(
            error.toString(),
            role: TextRole.detail,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Empty state when no commit is selected
class NoCommitSelectedState extends StatelessWidget {
  const NoCommitSelectedState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Hand-rolled, this was the facade's own layout copied out by hand, down
    // to the muted sentence under the headline. It says the same thing with
    // the size question deleted.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.cursorClick,
      title: l10n.emptyStateNoCommitSelected,
      message: l10n.emptyStateNoCommitSelectedMessage,
    );
  }
}

/// Empty state when search/filter returns no results
class NoSearchResultsState extends StatelessWidget {
  final VoidCallback onClearFilters;

  /// Non-null when the search only covered a partial window and widening it
  /// to the entire history is possible; renders the explicit offer to do so.
  final VoidCallback? onSearchAllHistory;

  const NoSearchResultsState({
    super.key,
    required this.onClearFilters,
    this.onSearchAllHistory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Stays hand-rolled, and the reason is the third line rather than the
    // mark. `EmptyStateSpec` has one sentence slot; this state has two - the
    // advice, and the caveat that the search only covered the loaded window -
    // and the caveat is `related` to the sentence above it while the facade
    // puts everything after the message a `separate` gap away. Its two ways
    // out disagree with the facade too: `EmptyStateAction` offers primary or
    // secondary, and "Clear filters" is deliberately quieter than both.
    // Folding either onto the nearest thing the facade can say would move
    // pixels, so it does not happen here.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(l10n.emptyStateNoResultsFound, role: TextRole.pageTitle),
          const BaseGap(Proximity.related),
          BaseLabel(
            l10n.emptyStateTryAdjustingSearchCriteria,
            role: TextRole.body,
            tone: Tone.muted,
          ),
          if (onSearchAllHistory != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(
              l10n.historySearchCoversLoadedOnly,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
          ],
          // The verbal statement and the actions offered under it are two
          // groups inside the one empty-state region: `separate`, the word
          // every other empty state uses at this boundary.
          const BaseGap(Proximity.separate),
          BaseButton(
            label: l10n.clearFiltersAction,
            variant: ButtonVariant.tertiary,
            leadingIcon: IconRole.x,
            onPressed: onClearFilters,
          ),
          if (onSearchAllHistory != null) ...[
            // Sibling actions in one run are members of one group:
            // `grouped`, the vocabulary's own exemplar for a run of actions.
            const BaseGap(Proximity.grouped),
            BaseButton(
              label: l10n.historySearchAllHistory,
              variant: ButtonVariant.secondary,
              leadingIcon: IconRole.listMagnifyingGlass,
              onPressed: onSearchAllHistory,
            ),
          ],
        ],
      ),
    );
  }
}
