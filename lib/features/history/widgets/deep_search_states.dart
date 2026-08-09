import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// Full-area state while git walks the entire history.
///
/// Deep search is a different, slower operation than the in-memory filter
/// and is presented as one: it takes over the list area, names itself, and
/// carries its own Cancel.
class DeepSearchRunningState extends StatelessWidget {
  const DeepSearchRunningState({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          // The indicator and the headline under it are two groups inside one
          // region, and so are the headline and the action offered under it:
          // `separate` at both boundaries, exactly as in every other empty
          // state of the application.
          const BaseGap(Proximity.separate),
          BaseLabel(l10n.historySearchingAllHistory, role: TextRole.pageTitle),
          const BaseGap(Proximity.separate),
          BaseButton(
            label: l10n.cancel,
            variant: ButtonVariant.secondary,
            leadingIcon: IconRole.x,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Banner above deep-search results: how many matched, whether the list is
/// capped, the way back to the loaded window, and optionally the escalation
/// to content (pickaxe) search.
class DeepSearchResultsBanner extends StatelessWidget {
  const DeepSearchResultsBanner({
    super.key,
    required this.matchCount,
    required this.capped,
    required this.cappedLimit,
    required this.onBack,
    this.onSearchChanges,
  });

  final int matchCount;
  final bool capped;
  final int cappedLimit;
  final VoidCallback onBack;

  /// Non-null when escalating to `-S` is possible (text query, not already
  /// a pickaxe run).
  final VoidCallback? onSearchChanges;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final summary = capped
        ? '${l10n.historyDeepSearchMatches(matchCount)}'
              ' (${l10n.historyDeepSearchCapped(cappedLimit)})'
        : l10n.historyDeepSearchMatches(matchCount);

    return Container(
      // The band's fill and its rule stay: they are the surface. How far it
      // holds its content off its own edge is the language's question.
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: BaseInset(
        child: Row(
          children: [
            const BaseIcon(
              IconRole.listMagnifyingGlass,
              scale: ControlScale.compact,
              tone: Tone.accent,
            ),
            const BaseGap(Proximity.related),
            Expanded(child: BaseLabel(summary, role: TextRole.detail)),
            if (onSearchChanges != null) ...[
              BaseButton(
                label: l10n.historyDeepSearchInChanges,
                variant: ButtonVariant.tertiary,
                size: ButtonSize.small,
                leadingIcon: IconRole.magnifyingGlass,
                onPressed: onSearchChanges,
              ),
              // Sibling actions in one run are members of one group:
              // `grouped`, the vocabulary's own exemplar for a run of
              // actions.
              const BaseGap(Proximity.grouped),
            ],
            BaseButton(
              label: l10n.historyDeepSearchBack,
              variant: ButtonVariant.tertiary,
              size: ButtonSize.small,
              leadingIcon: IconRole.x,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when the whole history holds no match - distinct from the
/// window-scoped "no results", which offers to widen the search.
class DeepSearchNoResultsState extends StatelessWidget {
  const DeepSearchNoResultsState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The facade, not a copy of it: mark, headline, sentence, and no size
    // written here. See history_empty_states.dart for why `ControlScale` was
    // never the answer to a hero mark's measure.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.magnifyingGlass,
      title: l10n.emptyStateNoResultsFound,
      message: l10n.historyDeepSearchNoMatches,
    );
  }
}

/// Error state for a failed whole-history search, with the way back.
class DeepSearchFailedState extends StatelessWidget {
  const DeepSearchFailedState({
    super.key,
    required this.error,
    required this.onBack,
  });

  final String error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // One of the two reasons this stayed hand-rolled is gone: the hero carries
    // a tone now (#431), so "this failed" is something `EmptyStateWidget` can
    // say in red. The surviving reason is shape, and it is enough on its own.
    // This state has no headline at all - a single sentence carrying the git
    // error - while the facade always renders a `pageTitle` above its message,
    // so the sentence would be promoted out of `body` into a slot it does not
    // belong in. Its way back disagrees too: `EmptyStateAction` offers primary
    // or secondary, and this button is deliberately quieter than both. The
    // read is stranded with the size the way it is inside the facade itself -
    // a tone reaches a mark only through a member or `BaseIcon`, whose scales
    // top out at 24 while this hero is 64.
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
          BaseLabel(
            l10n.historyDeepSearchFailed(error),
            role: TextRole.body,
            align: TextAlign.center,
          ),
          // The verbal statement and the action offered under it are two
          // groups inside the one empty-state region: `separate`, the word
          // every other empty state uses at this boundary.
          const BaseGap(Proximity.separate),
          BaseButton(
            label: l10n.historyDeepSearchBack,
            variant: ButtonVariant.tertiary,
            leadingIcon: IconRole.x,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}
