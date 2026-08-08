import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';

/// Empty state when repository has no commits
class NoCommitsState extends StatelessWidget {
  const NoCommitsState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.gitCommit,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseLabel(l10n.emptyStateNoCommits, role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(l10n.emptyStateNoCommitsMessage, role: TextRole.body),
        ],
      ),
    );
  }
}

/// Empty state showing error when loading history fails
class HistoryErrorState extends StatelessWidget {
  final Object error;

  const HistoryErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
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
          const BaseLabel('Error Loading History', role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.cursorClick,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseLabel(l10n.emptyStateNoCommitSelected, role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            l10n.emptyStateNoCommitSelectedMessage,
            role: TextRole.body,
            tone: Tone.muted,
          ),
        ],
      ),
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
          BaseLabel(l10n.emptyStateNoResultsFound, role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            l10n.emptyStateTryAdjustingSearchCriteria,
            role: TextRole.body,
            tone: Tone.muted,
          ),
          if (onSearchAllHistory != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BaseLabel(
              l10n.historySearchCoversLoadedOnly,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
          ],
          const SizedBox(height: AppTheme.paddingM),
          BaseButton(
            label: l10n.clearFiltersAction,
            variant: ButtonVariant.tertiary,
            leadingIcon: IconRole.x,
            onPressed: onClearFilters,
          ),
          if (onSearchAllHistory != null) ...[
            const SizedBox(height: AppTheme.paddingS),
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
