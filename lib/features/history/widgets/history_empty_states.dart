import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
          TitleLargeLabel(
            l10n.emptyStateNoCommits,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.emptyStateNoCommitsMessage,
          ),
        ],
      ),
    );
  }
}

/// Empty state showing error when loading history fails
class HistoryErrorState extends StatelessWidget {
  final Object error;

  const HistoryErrorState({
    super.key,
    required this.error,
  });

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
          TitleLargeLabel(
            'Error Loading History',
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            error.toString(),
            textAlign: TextAlign.center,
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
          TitleLargeLabel(
            l10n.emptyStateNoCommitSelected,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.emptyStateNoCommitSelectedMessage,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Empty state when search/filter returns no results
class NoSearchResultsState extends StatelessWidget {
  final VoidCallback onClearFilters;

  const NoSearchResultsState({
    super.key,
    required this.onClearFilters,
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
          TitleLargeLabel(
            l10n.emptyStateNoResultsFound,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.emptyStateTryAdjustingSearchCriteria,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingM),
          BaseButton(
            label: l10n.clearFiltersAction,
            variant: ButtonVariant.tertiary,
            leadingIcon: PhosphorIconsRegular.x,
            onPressed: onClearFilters,
          ),
        ],
      ),
    );
  }
}
