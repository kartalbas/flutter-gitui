import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_viewer_dialog.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../../history/widgets/commit_details_panel.dart';
import '../../history/widgets/file_tree_panel.dart';

/// File history panel - shows git history for a specific file
class FileHistoryPanel extends ConsumerWidget {
  final String filePath;

  const FileHistoryPanel({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final fileHistory = ref.watch(fileHistoryProvider(filePath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.fileHistory),
            BaseLabel(fileName, role: TextRole.detail, tone: Tone.muted),
          ],
        ),
        actions: [
          BaseIconButton(
            icon: IconRole.arrowClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: () {
              ref.invalidate(fileHistoryProvider(filePath));
            },
          ),
        ],
      ),
      body: fileHistory.when(
        data: (commits) => _buildCommitList(context, commits),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildCommitList(BuildContext context, List<GitCommit> commits) {
    if (commits.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.clockCounterClockwise,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.paddingL),
            BaseLabel(l10n.emptyStateNoHistory, role: TextRole.pageTitle),
            const SizedBox(height: AppTheme.paddingS),
            BaseLabel(l10n.emptyStateNoHistoryMessage, role: TextRole.body),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      itemCount: commits.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTheme.paddingS),
      itemBuilder: (context, index) =>
          _buildCommitCard(context, commits[index]),
    );
  }

  Widget _buildCommitCard(BuildContext context, GitCommit commit) {
    return BaseCard(
      padding: EdgeInsets.zero,
      content: InkWell(
        onTap: () => _viewCommitDiff(context, commit),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commit hash and author
              Row(
                children: [
                  // Hash badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingS,
                      vertical: AppTheme.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    // The badge paints its own fill and states the
                    // foreground that pairs with it.
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      child: BaseLabel(commit.shortHash, role: TextRole.detail),
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BaseLabel(
                      commit.author,
                      role: TextRole.body,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Flexible(
                    child: BaseLabel(
                      commit.authorDateDisplay(
                        Localizations.localeOf(context).languageCode,
                      ),
                      role: TextRole.detail,
                      tone: Tone.muted,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingS),
              // Commit message
              BaseLabel(commit.subject, role: TextRole.body),
              if (commit.body.isNotEmpty) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BaseLabel(
                  commit.body,
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
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
          BaseLabel(
            AppLocalizations.of(context)!.messageErrorLoadingHistory,
            role: TextRole.pageTitle,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(error, role: TextRole.body, align: TextAlign.center),
        ],
      ),
    );
  }

  void _viewCommitDiff(BuildContext context, GitCommit commit) {
    final l10n = AppLocalizations.of(context)!;

    // Show commit details with files in a dialog (similar to file blame panel and history screen)
    BaseViewerDialog.show(
      context: context,
      dialog: BaseViewerDialog(
        icon: IconRole.gitCommit,
        title: l10n.commitShortHash(commit.shortHash),
        subtitle: commit.subject,
        content: Row(
          children: [
            // Left: Commit details panel
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: CommitDetailsPanel(commit: commit),
              ),
            ),

            // Right: Changed files panel
            Expanded(flex: 1, child: FileTreePanel(commitHash: commit.hash)),
          ],
        ),
      ),
    );
  }
}
