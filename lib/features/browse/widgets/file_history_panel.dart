import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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

  const FileHistoryPanel({
    super.key,
    required this.filePath,
  });

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
            BodySmallLabel(
              fileName,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        actions: [
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowClockwise,
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
            TitleLargeLabel(
              l10n.emptyStateNoHistory,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              l10n.emptyStateNoHistoryMessage,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      itemCount: commits.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppTheme.paddingS),
      itemBuilder: (context, index) => _buildCommitCard(context, commits[index]),
    );
  }

  Widget _buildCommitCard(BuildContext context, GitCommit commit) {
    return BaseCard(
      padding: EdgeInsets.zero,
      content: InkWell(
        onTap: () => _viewCommitDiff(context, commit),
        borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: BodySmallLabel(
                      commit.shortHash,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodyMediumLabel(
                      commit.author,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Flexible(
                    child: BodySmallLabel(
                      commit.authorDateDisplay(Localizations.localeOf(context).languageCode),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingS),
              // Commit message
              BodyMediumLabel(
                commit.subject,
              ),
              if (commit.body.isNotEmpty) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  commit.body,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
          TitleLargeLabel(
            AppLocalizations.of(context)!.messageErrorLoadingHistory,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            error,
            textAlign: TextAlign.center,
          ),
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
        icon: PhosphorIconsRegular.gitCommit,
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
            Expanded(
              flex: 1,
              child: FileTreePanel(commitHash: commit.hash),
            ),
          ],
        ),
      ),
    );
  }
}
