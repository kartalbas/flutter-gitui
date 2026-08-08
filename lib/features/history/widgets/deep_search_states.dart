import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';

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
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(l10n.historySearchingAllHistory),
          const SizedBox(height: AppTheme.paddingM),
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
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.listMagnifyingGlass,
            size: AppTheme.iconS,
            color: scheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingS),
          Expanded(child: BodySmallLabel(summary)),
          if (onSearchChanges != null) ...[
            BaseButton(
              label: l10n.historyDeepSearchInChanges,
              variant: ButtonVariant.tertiary,
              size: ButtonSize.small,
              leadingIcon: IconRole.magnifyingGlass,
              onPressed: onSearchChanges,
            ),
            const SizedBox(width: AppTheme.paddingS),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(l10n.emptyStateNoResultsFound),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.historyDeepSearchNoMatches,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BodyMediumLabel(
            l10n.historyDeepSearchFailed(error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.paddingM),
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
