import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';

/// The last row of the history list: the one place that says whether the
/// list ends because the history ends or because the loaded window does.
///
/// Exactly one of three faces:
/// - more history exists: a Load button naming the page size, with progress
///   and inline-error-with-retry variants while a page is in flight or has
///   failed;
/// - the window reaches the root: a terminal marker naming the total, so
///   "end of history" and "end of what is loaded" can never be confused;
/// - a search is active on a partial window: the Load button plus the offer
///   to run the search over the entire history instead.
class HistoryListFooter extends StatelessWidget {
  const HistoryListFooter({
    super.key,
    required this.loadedCount,
    required this.hasMore,
    required this.isLoadingMore,
    required this.pageSize,
    required this.onLoadMore,
    this.loadMoreError,
    this.searchActive = false,
    this.onSearchAllHistory,
  });

  final int loadedCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final int pageSize;
  final bool searchActive;
  final VoidCallback onLoadMore;

  /// Non-null only when a deep search would mean something: a filter is
  /// active, expressible by git, and the window does not cover everything.
  final VoidCallback? onSearchAllHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (!hasMore) {
      // The affordance for "this is genuinely the end": non-interactive and
      // visually distinct from the loadable state.
      return Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.flagCheckered,
              size: AppTheme.iconS,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppTheme.paddingS),
            BaseLabel(
              l10n.historyBeginningOfHistory(loadedCount),
              role: TextRole.detail,
              tone: Tone.muted,
            ),
          ],
        ),
      );
    }

    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: AppTheme.iconS,
              height: AppTheme.iconS,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppTheme.paddingS),
            BaseLabel(
              l10n.historyLoadingMoreCommits,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: Column(
        children: [
          if (loadMoreError != null) ...[
            BaseLabel(
              l10n.historyLoadMoreFailed(loadMoreError!),
              role: TextRole.detail,
              tone: Tone.danger,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingS),
          ],
          BaseButton(
            label: loadMoreError == null
                ? l10n.historyLoadMoreCommits(pageSize)
                : l10n.retry,
            variant: ButtonVariant.secondary,
            size: ButtonSize.small,
            leadingIcon: IconRole.caretDoubleDown,
            onPressed: onLoadMore,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            l10n.historyLoadedCount(loadedCount),
            role: TextRole.detail,
            tone: Tone.muted,
          ),
          if (searchActive && onSearchAllHistory != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BaseButton(
              label: l10n.historySearchAllHistory,
              variant: ButtonVariant.tertiary,
              size: ButtonSize.small,
              leadingIcon: IconRole.listMagnifyingGlass,
              onPressed: onSearchAllHistory,
            ),
          ],
        ],
      ),
    );
  }
}
